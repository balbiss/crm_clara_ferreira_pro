# Lógica de entrada de mensagem da WAHA, compartilhada entre o webhook
# (tempo real) e o WahaHistorySyncJob (importação do histórico que ficou
# pra trás enquanto o WhatsApp estava deslogado/caído). Mesmo formato de
# payload nos dois casos: o GET /api/{session}/chats/{id}/messages da WAHA
# devolve exatamente o que o evento message.any manda.
module WahaMessageIngestion
  # _data.type de eventos de PROTOCOLO do WhatsApp Business (handshake de
  # privacidade, placeholder de conteúdo, etc.) — nunca é mensagem de
  # verdade. Lista curada a partir de eventos reais vistos em produção
  # (2026-08-31); se aparecer um tipo novo desse tipo no futuro, some
  # da lista de "Arquivo não suportado ou vazio" e precisa ser adicionado aqui.
  TIPOS_SISTEMA_SEM_CONTEUDO = %w[
    notification_template
    biz_content_placeholder
    e2e_notification
    gp2
    call_log
    ciphertext
    protocol
  ].freeze

  private

  # historical: true = mensagem importada do histórico (WahaHistorySyncJob),
  # não chegando agora. Muda só o "efeito colateral": grava com a data
  # original, não aciona IA/Fluxo/pausa de IA, não notifica nem faz
  # broadcast, e a deduplicação também compara pelo final do id (ver
  # already_imported?). Contato/conversa/mídia seguem a mesma lógica.
  # Retorna o Message criado (ou nil se já existia/foi ignorado).
  def handle_message(inbox, payload, historical: false)
    payload = payload.with_indifferent_access if payload.respond_to?(:with_indifferent_access)

    source_id = payload[:id]
    return if source_id.blank?
    return if historical && already_imported?(inbox, payload)

    # O id da WAHA vem no formato "{fromMe}_{chatId}_{messageId}" (mesmo
    # padrão do whatsapp-web.js) — é a fonte mais confiável do chat/contato,
    # igual pras mensagens que nós mandamos (fromMe true) quanto pras que
    # chegam do cliente. "from"/"to" isolados são ambíguos dependendo da
    # direção, por isso não são usados como fonte primária aqui.
    id_parts = source_id.to_s.split('_')
    chat_id = id_parts.length >= 3 ? id_parts[1] : (payload[:fromMe] ? payload[:to] : payload[:from])
    return if chat_id.blank?

    # Grupo vira conversa normal na tela (dono pediu, 2026-09-25), mas NUNCA
    # aciona Fluxo nem IA (guardas mais abaixo) — só pra leitura/resposta
    # manual do time. Não cria "cadastro" de revendedora nenhum pro grupo:
    # o Contact é só um container técnico pra conversa existir (status
    # dedicado 'grupo', fora de ACTIVE_STATUSES/INACTIVE_STATUSES — mesmo
    # padrão do 'atacado' — nunca aparece em Carteira/Inativas/régua).
    is_group = chat_id.end_with?('@g.us')

    # "status@broadcast" é o Status/Stories do WhatsApp (atualização que um
    # contato posta, não conversa nenhuma) — o whatsapp-web.js/WAHA repassa
    # isso pro webhook igual a mensagem de verdade. Sem esse filtro virava
    # um "contato" com telefone literalmente "status" e o vídeo/foto do
    # Story de alguém aparecendo como se fosse mensagem recebida (visto ao
    # vivo, 2026-09-21 — contato "status" #609 com vídeo de story anexado).
    return if chat_id == 'status@broadcast'

    from_me = payload[:fromMe]
    human_reply_via_phone = false

    if from_me && historical
      # Mandada pelo celular (ou pelo CRM, já filtrado em already_imported?)
      # enquanto o CRM não recebia nada — entra como resposta da equipe, mas
      # sem pausar IA nem etiquetar: é passado, não intervenção acontecendo agora.
      human_reply_via_phone = true
    elsif from_me
      if Message.exists?(source_id: source_id)
        return # eco da própria IA/CRM já salvo antes
      end
      # Guarda contra a corrida entre "acabamos de mandar isso" (IA ou
      # Fluxo, ver FlowRunnerService) e o eco (fromMe: true) chegando
      # antes do Message local ser gravado com o source_id certo — sem
      # isso o eco vira uma SEGUNDA mensagem, tratada como intervenção
      # humana via celular (visto ao vivo num teste real de Fluxo em
      # 2026-08-31). Não depende de inbox.ai_enabled: Fluxo manda mensagem
      # mesmo com a IA desligada.
      if Rails.cache.read("ai_is_replying_#{inbox.id}_#{chat_id}")
        return
      end

      # Eco de mensagem que o próprio CRM acabou de mandar (MessagesController#create)
      # chegando antes do source_id ser gravado no Message original — ver comentário
      # em messages_controller.rb. Sem isso, viraria uma SEGUNDA mensagem duplicada.
      if Rails.cache.read("sending_from_crm_#{inbox.id}_#{chat_id}")
        return
      end

      # Intervenção humana real, feita direto pelo celular — precisa ser
      # salva (senão nunca aparece na conversa) e pausa a IA, igual ao
      # comportamento equivalente no webhook do Baileys.
      human_reply_via_phone = true
      if inbox.ai_enabled
        Rails.logger.info("IA pausada para #{chat_id} (Waha) devido a intervenção humana (fromMe).")
        Rails.cache.write("ai_paused_#{inbox.id}_#{chat_id}", Time.current.to_i)
        Thread.new do
          begin
            conv = inbox.conversations.joins(:contact).where(contacts: { jid: chat_id }).first
            if conv
              tag = conv.account.tags.find_or_create_by!(name: 'agente_off') { |t| t.color = '#f97316' }
              conv.tags << tag unless conv.tags.include?(tag)
              ActionCable.server.broadcast("conversations_channel_#{conv.account_id}", {
                event: 'conversation_tags_updated',
                conversation_id: conv.id,
                tags: conv.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
              })
            end
          rescue => e
            Rails.logger.error("Erro ao aplicar tag agente_off (Waha): #{e.message}")
          end
        end
      end
    end

    return if Message.exists?(source_id: source_id)

    # Notificações internas do protocolo do WhatsApp Business (negociação
    # de privacidade, cartão de contato, placeholder de conteúdo biz) —
    # não são mensagem nenhuma, mas a WAHA repassa pro webhook igual (visto
    # ao vivo em 2026-08-31: 3-4 desses chegaram em menos de 1s pro mesmo
    # chat, sem texto nem mídia real, e viravam "📎 Arquivo não suportado
    # ou vazio" na tela — além de terem disparado uma corrida que criou
    # Contact duplicado, ver migração idx_contacts_account_jid_unique).
    # Só ignora quando não tem NENHUM conteúdo de verdade (texto/mídia) —
    # uma mensagem real desses tipos nunca cairia aqui.
    tipo_evento = payload[:_data].is_a?(Hash) ? payload[:_data][:type] : nil
    if payload[:body].to_s.blank? && !payload[:hasMedia] && TIPOS_SISTEMA_SEM_CONTEUDO.include?(tipo_evento)
      Rails.logger.info("[Webhooks::Waha] evento de sistema sem conteúdo ignorado (tipo=#{tipo_evento.inspect}) chat_id=#{chat_id}")
      return
    end

    account = inbox.account

    if is_group
      contact = Contact.find_by(account_id: account.id, jid: chat_id)
      contact ||= begin
        group_name = WhatsappWahaService.new(inbox).fetch_group_name(chat_id)
        Contact.create!(account_id: account.id, jid: chat_id, status: 'grupo', source: 'WhatsApp') do |c|
          c.name = group_name.presence || "Grupo #{chat_id.split('@').first}"
        end
      rescue ActiveRecord::RecordNotUnique
        Contact.find_by(account_id: account.id, jid: chat_id)
      end
      contact_phone_formatted = contact.name
    else
      # "@lid" é o identificador de privacidade novo do WhatsApp — substitui
      # o número de telefone real em algumas conversas (confirmado num
      # teste real: sem isso o contato nascia com nome/telefone
      # "+49444250742890", que não existe, são só os dígitos do lid).
      # Resolve pro contato de verdade via GET /api/contacts antes de
      # casar/criar o Contact.
      resolved_number = nil
      resolved_name = nil
      if chat_id.end_with?('@lid')
        resolved = WhatsappWahaService.new(inbox).resolve_contact(chat_id)
        if resolved && resolved['id'].present?
          resolved_number = resolved['id'].to_s.split('@').first
          saved_name = resolved['name'].presence
          # A WAHA devolve "name" == "number" quando não há nome salvo na
          # agenda do WhatsApp conectado — nesse caso não serve como nome.
          resolved_name = saved_name if saved_name.present? && saved_name != resolved['number']
          resolved_name ||= resolved['pushname'].presence
        end
      end

      contact_phone = resolved_number || chat_id.split('@').first
      contact_phone_formatted = contact_phone.match?(/\A\d+\z/) ? "+#{contact_phone}" : contact_phone

      contact = Contact.find_by_any_phone(account.id, contact_phone_formatted)
      # Mesmo chat já ligado a um contato com outro telefone (ex: @lid
      # resolvido diferente) — reaproveita em vez de bater no índice único
      # de jid e depender do rescue abaixo.
      contact ||= Contact.find_by(account_id: account.id, jid: chat_id)
      contact ||= begin
        Contact.create!(account_id: account.id, phone: contact_phone_formatted) do |c|
          c.name = resolved_name.presence
          c.name ||= payload[:_data].is_a?(Hash) ? payload[:_data][:notifyName].presence : nil
          c.name ||= contact_phone_formatted
          c.jid = chat_id
          c.source = 'WhatsApp'
        end
      rescue ActiveRecord::RecordNotUnique
        # 2+ webhooks pro mesmo chat processados em paralelo (visto ao vivo,
        # ver idx_contacts_account_jid_unique) — quem perdeu a corrida busca
        # de novo em vez de duplicar.
        Contact.find_by_any_phone(account.id, contact_phone_formatted) || Contact.find_by(account_id: account.id, jid: chat_id)
      end
    end

    if contact.status == 'blocked'
      Rails.logger.info("Mensagem ignorada (Waha): contato #{contact_phone_formatted} está bloqueado")
      return
    end

    # Só grava o jid se nenhum OUTRO contato já for dono dele (índice único) —
    # acontece com cadastro duplicado da mesma pessoa (ex: #27 do Jueri sem
    # jid e #695 criado pelo WhatsApp, mesmo telefone): o update estourava
    # RecordNotUnique e a mensagem inteira se perdia, ao vivo e na importação.
    if contact.jid != chat_id && !Contact.where(account_id: account.id, jid: chat_id).where.not(id: contact.id).exists?
      contact.update(jid: chat_id)
    end

    # Auto-cura pra contato @lid, em 2 passos independentes — rodam a cada
    # mensagem nova, em background:
    #
    # 1) Se o telefone salvo ainda for literalmente os dígitos do lid (ver
    #    "Victor Ferreira" ficou com "+43692870107202", 2026-09-21), tenta
    #    resolver o número real de novo — a WAHA pode ter aprendido o
    #    contato depois da 1ª mensagem.
    #
    # 2) SEMPRE checa se já existe outro contato de verdade com esse
    #    telefone (ex: sincronizado do Jueri) — não só quando acabou de
    #    resolver agora. Bug real achado ao vivo: telefone do #615 já
    #    tinha sido corrigido numa mensagem anterior, então o passo 1 não
    #    rodava mais nunca, e a checagem de duplicata (que só existia
    #    DENTRO do passo 1) nunca chegava a rodar — o #618 "Testes Victor"
    #    (mesma pessoa, cadastro do Jueri) só ganhou o telefone certo
    #    DEPOIS, numa sincronização posterior, e a mensagem nova do Victor
    #    não disparou a mesclagem. Separar os dois passos cobre isso.
    # Na importação em lote não dispara thread por mensagem (seriam centenas);
    # a próxima mensagem ao vivo desse contato faz a auto-cura normalmente.
    if chat_id.end_with?('@lid') && !historical
      Thread.new do
        begin
          lid_digits = chat_id.split('@').first

          if contact.phone == "+#{lid_digits}"
            retry_resolved = WhatsappWahaService.new(inbox).resolve_contact(chat_id)
            real_number = retry_resolved && retry_resolved['id'].present? ? retry_resolved['id'].to_s.split('@').first : nil

            if real_number.present? && real_number != lid_digits
              updates = { phone: "+#{real_number}" }
              if contact.name == contact_phone_formatted
                saved_name = retry_resolved['name'].presence
                saved_name = nil if saved_name == retry_resolved['number']
                updates[:name] = saved_name || retry_resolved['pushname'].presence || updates[:phone]
              end
              contact.update(updates)
            end
          end

          existing_match = Contact.find_by_any_phone(account.id, contact.phone)
          if existing_match && existing_match.id != contact.id
            # Já existe um cadastro de verdade com esse telefone (ex:
            # revendedora sincronizada do Jueri) — o contato criado às
            # cegas pelo @lid é só um duplicado temporário, então a
            # conversa vai pro cadastro certo em vez de deixar o dono
            # vendo um "novo contato" vazio ao lado dos dados reais da
            # pessoa. Mesma mecânica do ContactsController#merge (mover
            # conversas + destruir o duplicado), só que automática.
            existing_match.update(jid: chat_id) if existing_match.jid != chat_id
            contact.conversations.update_all(contact_id: existing_match.id)
            contact.destroy
          end
        rescue => e
          Rails.logger.error("Failed to re-resolve/merge lid contact (Waha) for #{chat_id}: #{e.message}")
        end
      end
    end

    if contact.avatar_url.blank? && !historical
      Thread.new do
        begin
          url = WhatsappWahaService.new(inbox).fetch_profile_picture_url(chat_id)
          contact.update(avatar_url: url) if url.present?
        rescue => e
          Rails.logger.error("Failed to fetch profile picture (Waha) for #{chat_id}: #{e.message}")
        end
      end
    end

    conversation = Conversation.find_or_create_by(contact: contact, inbox: inbox) do |conv|
      conv.status = :open
      conv.account = account
    end

    text = payload[:body].to_s

    message_attrs = {
      account: conversation.account,
      conversation: conversation,
      text: text,
      sender_type: human_reply_via_phone ? 'User' : 'Contact',
      sender_id: human_reply_via_phone ? nil : contact.id,
      source_id: source_id,
      status: :delivered
    }
    if historical
      message_attrs[:created_at] = Time.zone.at(payload[:timestamp].to_i) if payload[:timestamp].to_i.positive?
      message_attrs[:historical_import] = true
    end
    message_record = Message.create!(message_attrs)

    # Mídia do histórico: baixa na hora (já estamos num job, não na request do
    # webhook) e sem IA/transcrição — o resto do fluxo abaixo é só tempo real.
    if historical
      attach_historical_media(inbox, message_record, payload)
      return message_record
    end

    # Mídia: a WAHA baixa o arquivo sozinha e devolve uma URL própria pra
    # gente buscar (mesmo padrão de "baixar com a API key" do Baileys).
    if payload[:hasMedia] && payload[:media].is_a?(Hash)
      media = payload[:media]
      media_url = media[:url]
      mimetype = media[:mimetype].presence || 'application/octet-stream'

      if media_url.present?
        # Download roda em background: cada tentativa contra a WAHA pode
        # demorar até open_timeout+read_timeout (visto ao vivo travando o
        # processo Rails inteiro por 4-6min em mídia de status@broadcast
        # que a WAHA não consegue servir — sem timeout explícito o
        # Net::HTTP.start usava o default de 60s, 3x seguidas, dentro da
        # própria request do webhook, esgotando as threads do Puma e
        # travando até o login). Timeouts curtos aqui = falha rápido;
        # rodar em Thread.new = nunca bloqueia o worker que responde ao
        # webhook, igual ao padrão já usado abaixo pra foto de perfil/IA.
        Thread.new do
          begin
            decoded_media = nil
            [0, 2, 4].each do |wait_seconds|
              sleep wait_seconds if wait_seconds.positive?
              begin
                uri = URI.parse(media_url)
                req = Net::HTTP::Get.new(uri)
                req['X-Api-Key'] = inbox.api_key.presence || ENV['WAHA_API_KEY']
                res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 10) { |http| http.request(req) }
                decoded_media = res.body if res.is_a?(Net::HTTPSuccess)
              rescue => e
                Rails.logger.error("Failed to download Waha media for message #{source_id} (tentativa #{wait_seconds}s): #{e.message}")
              end
              break if decoded_media.present?
            end

            if decoded_media.present?
              extension = mimetype.split('/').last&.split(';')&.first || 'bin'
              message_record.attachment.attach(
                io: StringIO.new(decoded_media),
                filename: media[:filename].presence || "#{source_id}.#{extension}",
                content_type: mimetype
              )

              if mimetype.start_with?('audio/') && inbox.ai_enabled
                begin
                  transcription = AiAssistantService.transcribe_audio(decoded_media, "#{source_id}.#{extension}", inbox)
                  message_record.update(text: "[Áudio Transcrito] #{transcription}") if transcription.present?
                rescue => e
                  Rails.logger.error("Erro no Whisper (Waha): #{e.message}")
                end
              end

              message_record.update(text: '📎 Anexo recebido') if message_record.text.blank?
            else
              message_record.update(text: '📎 Arquivo não pôde ser baixado') if message_record.text.blank?
            end

            message_record.rebroadcast
          rescue => e
            Rails.logger.error("Erro fatal no download de mídia (Waha) para #{source_id}: #{e.message}")
          end
        end
      end
    elsif message_record.text.blank?
      message_record.update(text: '📎 Arquivo não suportado ou vazio')
    end

    media_download_started_in_background = payload[:hasMedia] && payload[:media].is_a?(Hash) && payload[:media][:url].present?
    message_record.rebroadcast unless media_download_started_in_background

    # Fluxos — se essa conversa tem um Fluxo esperando resposta (Perguntar/
    # Botões), essa mensagem É a resposta, checado antes do gatilho por
    # palavra-chave. Se algum Fluxo assumir (resposta OU gatilho novo), a
    # IA não entra (mesma prioridade que intervenção humana tem sobre ela).
    # Grupo NUNCA aciona Fluxo nem IA (dono pediu explicitamente, 2026-09-25)
    # — só serve pra leitura/resposta manual do time.
    flow_handled = !human_reply_via_phone && !from_me && !is_group && (
      FlowRunnerService.continue_with_reply(conversation, text) ||
      FlowRunnerService.trigger_by_keyword(inbox, conversation, contact, text)
    )

    # ===== MOTOR DE INTELIGÊNCIA ARTIFICIAL (mesma lógica do Baileys) =====
    if inbox.ai_enabled && !human_reply_via_phone && !flow_handled && !is_group
      is_paused = Rails.cache.read("ai_paused_#{inbox.id}_#{chat_id}")

      if is_paused
        Rails.logger.info("IA pulou atendimento (Waha) para #{chat_id} porque está em cooldown (Humano assumiu).")
      else
        if conversation.status == 'resolved'
          conversation.update!(status: :open)
          tags_a_remover = conversation.tags.select { |t| %w[agente_off com_atendente].include?(t.name) }
          tags_a_remover.each { |t| conversation.conversation_tags.where(tag_id: t.id).delete_all }
          conversation.tags.reset
          ActionCable.server.broadcast("conversations_channel_#{conversation.account_id}", {
            event:        'conversation_updated',
            conversation: { id: conversation.id, status: 'open', snoozed_until: nil }
          })
          if tags_a_remover.any?
            ActionCable.server.broadcast("conversations_channel_#{conversation.account_id}", {
              event: 'conversation_tags_updated',
              conversation_id: conversation.id,
              tags: conversation.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
            })
          end
        elsif conversation.status == 'snoozed'
          conversation.update!(status: :open, snoozed_until: nil)
          ActionCable.server.broadcast("conversations_channel_#{conversation.account_id}", {
            event:           'snooze_expired',
            conversation_id: conversation.id,
            contact_name:    contact.name.presence || contact.phone,
            reason:          'client_message'
          })
          ActionCable.server.broadcast("conversations_channel_#{conversation.account_id}", {
            event:        'conversation_updated',
            conversation: { id: conversation.id, status: 'open', snoozed_until: nil }
          })
        end

        debounce_key = "debounce_ai_#{inbox.id}_#{chat_id}"
        current_time = Time.now.to_f
        Rails.cache.write(debounce_key, current_time)

        Thread.new do
          begin
            sleep 8

            if Rails.cache.read(debounce_key) == current_time
              Rails.logger.info("Iniciando AiAssistantService (Waha) para a conversa #{conversation.id}")

              ai_service = AiAssistantService.new(inbox, conversation)
              ai_response_text = ai_service.process_message

              if ai_response_text.present?
                Rails.cache.write("ai_is_replying_#{inbox.id}_#{chat_id}", true, expires_in: 60.seconds)

                paragraphs = ai_response_text.is_a?(Array) ? ai_response_text : ai_response_text.split("\n\n").reject(&:blank?)

                paragraphs.each do |paragraph|
                  WhatsappWahaService.new(inbox).send_presence_update(chat_id, 'composing')

                  typing_time = [(paragraph.length / 15.0).round, 3].max
                  typing_time = [typing_time, 15].min
                  sleep typing_time

                  Rails.cache.write("ai_is_replying_#{inbox.id}_#{chat_id}", true, expires_in: 30.seconds)

                  WhatsappWahaService.new(inbox).send_presence_update(chat_id, 'paused')

                  waha_id = WhatsappWahaService.new(inbox).send_message(chat_id, paragraph.strip)

                  Message.create!(
                    account: conversation.account,
                    conversation: conversation,
                    text: paragraph.strip,
                    sender_type: 'User',
                    sender_id: nil,
                    source_id: waha_id.presence || "ai_#{SecureRandom.hex(8)}",
                    status: :delivered
                  )
                end
              end
            else
              Rails.logger.info("Debounce cancelou a execução da IA (Waha, nova mensagem recebida) para #{chat_id}")
            end
          rescue => e
            Rails.logger.error("Erro fatal no AiAssistantService (Waha): #{e.message}")
          end
        end
      end
    end
    # ============================================
    message_record
  end

  # O mesmo envio aparece com ids diferentes dependendo de como a WAHA
  # enxerga o chat — "true_5514...@c.us_3EB0..." no eco ao vivo e
  # "true_9837...@lid_3EB0..." no histórico (medido em produção, 2026-10-01:
  # 192 de ~3.700 mensagens de 3 dias). O final do id (o id real da
  # mensagem no WhatsApp) é o mesmo nos dois, então compara por ele também.
  def already_imported?(inbox, payload)
    source_id = payload[:id].to_s
    return true if Message.exists?(source_id: source_id)

    # Formato "{fromMe}_{chatId}_{msgId}" — em grupo vem um 4º pedaço
    # (participante): "{fromMe}_{grupo}_{msgId}_{participante}". O id da
    # mensagem é sempre o 3º pedaço, nunca o último.
    msg_key = source_id.split('_')[2].to_s
    if msg_key.length >= 10
      key = Message.sanitize_sql_like(msg_key)
      return true if Message.where(account_id: inbox.account_id)
                            .where('source_id LIKE ? OR source_id LIKE ?', "%\\_#{key}", "%\\_#{key}\\_%")
                            .exists?
    end

    # Mensagem enviada pelo CRM/IA/Fluxo cujo envio não devolveu o id da
    # WAHA (source_id virou "ai_xxx"/"flow_xxx"...) — sem essa checagem, o
    # histórico traria uma cópia dela. Mesmo texto, mesma conversa, ±3 min.
    if payload[:fromMe] && payload[:body].present? && payload[:timestamp].to_i.positive?
      sent_at = Time.zone.at(payload[:timestamp].to_i)
      return true if Message.joins(:conversation)
                            .where(conversations: { inbox_id: inbox.id }, sender_type: 'User', text: payload[:body].to_s)
                            .where(created_at: (sent_at - 3.minutes)..(sent_at + 3.minutes))
                            .exists?
    end

    false
  end

  def attach_historical_media(inbox, message_record, payload)
    media = payload[:media]
    if payload[:hasMedia] && media.is_a?(Hash) && media[:url].present?
      begin
        uri = URI.parse(media[:url])
        req = Net::HTTP::Get.new(uri)
        req['X-Api-Key'] = inbox.api_key.presence || ENV['WAHA_API_KEY']
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 20) { |http| http.request(req) }
        if res.is_a?(Net::HTTPSuccess) && res.body.present?
          mimetype = media[:mimetype].presence || 'application/octet-stream'
          extension = mimetype.split('/').last&.split(';')&.first || 'bin'
          message_record.attachment.attach(
            io: StringIO.new(res.body),
            filename: media[:filename].presence || "#{message_record.source_id.to_s.split('_')[2]}.#{extension}",
            content_type: mimetype
          )
        end
      rescue => e
        Rails.logger.error("[WahaHistorySync] falha ao baixar mídia de #{message_record.source_id}: #{e.message}")
      end
    end

    if message_record.text.blank?
      message_record.update(text: message_record.attachment.attached? ? '📎 Anexo recebido' : (payload[:hasMedia] ? '📎 Arquivo não pôde ser baixado' : '📎 Arquivo não suportado ou vazio'))
    end
  end
end
