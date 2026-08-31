module Webhooks
  class WahaController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

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

    def create
      inbox = Inbox.find_by(id: params[:inbox_id], provider: 'waha')
      return render json: { status: 'ignored' } unless inbox

      event = params[:event]
      # params[:payload] chega como ActionController::Parameters aninhado —
      # `payload[:_data].is_a?(Hash)` e `payload[:media].is_a?(Hash)` sempre
      # davam falso sem essa conversão explícita (Parameters não é Hash),
      # o que quebrava silenciosamente tanto o nome via notifyName quanto o
      # download de mídia. to_unsafe_h converte tudo recursivamente.
      raw_payload = params[:payload]
      payload = raw_payload.respond_to?(:to_unsafe_h) ? raw_payload.to_unsafe_h.with_indifferent_access : (raw_payload || {}).with_indifferent_access

      if event == 'message.any'
        handle_message(inbox, payload)
      elsif event == 'session.status'
        handle_session_status(inbox, payload)
      end

      render json: { status: 'ok' }
    rescue StandardError => e
      Rails.logger.error("Waha webhook error: #{e.message}")
      render json: { status: 'error', message: e.message }, status: :internal_server_error
    end

    private

    def handle_session_status(inbox, payload)
      status = payload[:status] || payload['status']
      return if status.blank?

      # Traduz o vocabulário da WAHA (STARTING/SCAN_QR_CODE/WORKING/FAILED/STOPPED)
      # pro mesmo vocabulário que o frontend já entende do Baileys ('open' = conectado).
      Rails.cache.write("inbox:#{inbox.id}:status", status == 'WORKING' ? 'open' : 'close')

      ActionCable.server.broadcast("conversations_channel_#{inbox.account_id}", {
        event: 'inbox_updated',
        inbox_id: inbox.id,
        connection_status: status == 'WORKING' ? 'open' : 'close',
        qr_code: nil # frontend já busca o QR ao vivo via GET /inboxes/:id/qr_code
      })
    end

    def handle_message(inbox, payload)
      payload = payload.with_indifferent_access if payload.respond_to?(:with_indifferent_access)

      source_id = payload[:id]
      return if source_id.blank?

      # O id da WAHA vem no formato "{fromMe}_{chatId}_{messageId}" (mesmo
      # padrão do whatsapp-web.js) — é a fonte mais confiável do chat/contato,
      # igual pras mensagens que nós mandamos (fromMe true) quanto pras que
      # chegam do cliente. "from"/"to" isolados são ambíguos dependendo da
      # direção, por isso não são usados como fonte primária aqui.
      id_parts = source_id.to_s.split('_')
      chat_id = id_parts.length >= 3 ? id_parts[1] : (payload[:fromMe] ? payload[:to] : payload[:from])
      return if chat_id.blank?

      # Ignora mensagens de grupo
      return if chat_id.include?('@g.us')

      from_me = payload[:fromMe]
      human_reply_via_phone = false

      if from_me
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

      # "@lid" é o identificador de privacidade novo do WhatsApp — substitui o
      # número de telefone real em algumas conversas (confirmado num teste
      # real: sem isso o contato nascia com nome/telefone "+49444250742890",
      # que não existe, são só os dígitos do lid). Resolve pro contato de
      # verdade via GET /api/contacts antes de casar/criar o Contact.
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

      account = inbox.account

      contact = Contact.find_by_any_phone(account.id, contact_phone_formatted)
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

      if contact.status == 'blocked'
        Rails.logger.info("Mensagem ignorada (Waha): contato #{contact_phone_formatted} está bloqueado")
        return
      end

      contact.update(jid: chat_id) if contact.jid != chat_id

      if contact.avatar_url.blank?
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

      message_record = Message.create!(
        account: conversation.account,
        conversation: conversation,
        text: text,
        sender_type: human_reply_via_phone ? 'User' : 'Contact',
        sender_id: human_reply_via_phone ? nil : contact.id,
        source_id: source_id,
        status: :delivered
      )

      # Mídia: a WAHA baixa o arquivo sozinha e devolve uma URL própria pra
      # gente buscar (mesmo padrão de "baixar com a API key" do Baileys).
      if payload[:hasMedia] && payload[:media].is_a?(Hash)
        media = payload[:media]
        media_url = media[:url]
        mimetype = media[:mimetype].presence || 'application/octet-stream'

        if media_url.present?
          decoded_media = nil
          [0, 2, 4].each do |wait_seconds|
            sleep wait_seconds if wait_seconds.positive?
            begin
              uri = URI.parse(media_url)
              req = Net::HTTP::Get.new(uri)
              req['X-Api-Key'] = inbox.api_key.presence || ENV['WAHA_API_KEY']
              res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
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
        end
      elsif message_record.text.blank?
        message_record.update(text: '📎 Arquivo não suportado ou vazio')
      end

      message_record.rebroadcast

      # Fluxos — se essa conversa tem um Fluxo esperando resposta (Perguntar/
      # Botões), essa mensagem É a resposta, checado antes do gatilho por
      # palavra-chave. Se algum Fluxo assumir (resposta OU gatilho novo), a
      # IA não entra (mesma prioridade que intervenção humana tem sobre ela).
      flow_handled = !human_reply_via_phone && !from_me && (
        FlowRunnerService.continue_with_reply(conversation, text) ||
        FlowRunnerService.trigger_by_keyword(inbox, conversation, contact, text)
      )

      # ===== MOTOR DE INTELIGÊNCIA ARTIFICIAL (mesma lógica do Baileys) =====
      if inbox.ai_enabled && !human_reply_via_phone && !flow_handled
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
    end
  end
end
