class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    page  = (params[:page] || 1).to_i
    limit = (params[:per_page] || 100).to_i.clamp(1, 500)

    base = current_user.account.conversations

    # Consultor/atendente só veem conversas atribuídas a eles (não mostrar
    # não-atribuídas evita que fujam da fila do rodízio). Gerente/diretoria/
    # financeiro (full_portfolio?/finance?) veem tudo — mesma regra de
    # ContactsController#visible_contacts_scope.
    #
    # CORRIGIDO: antes só restringia role == 'atendente' (nomenclatura antiga),
    # deixando o role novo 'consultor' ver todas as conversas da conta sem
    # filtro nenhum — vazamento igual ao que corrigimos em ContactsController.
    unless full_portfolio? || finance? || current_user.has_permission?('admin')
      base = base.where(user_id: current_user.id)
    end

    conversations = base
      .includes(:user, :tags, messages: { attachment_attachment: :blob }, contact: { notes: :user, pedidos: {}, reseller_phones: {}, lifecycle_events: {} })
      .order(last_activity_at: :desc)
      .offset((page - 1) * limit).limit(limit)

    users_hash = current_user.account.users.index_by(&:id)
    render json: conversations.map { |conv| format_conversation(conv, users_hash) }
  end

  # POST /conversations — inicia conversa com uma revendedora que ainda não
  # tem nenhuma (sem isso, só existia conversa depois que ELA mandasse a
  # primeira mensagem — a régua pede o contrário: consultor manda a mensagem
  # de incentivo no 3º/10º/20º dia, briefing seção 12/23, e não tinha como).
  def create
    contact = visible_contacts_scope.find(params[:contact_id])
    inbox = pick_inbox_for(contact)

    unless inbox
      return render json: { error: 'sem_caixa_conectada', message: 'Nenhuma caixa de WhatsApp conectada nesta conta ainda.' }, status: :unprocessable_entity
    end

    conversation = Conversation.find_or_create_by(contact: contact, inbox: inbox) do |conv|
      conv.account = current_user.account
      conv.status = :open
      conv.user_id = contact.user_id || current_user.id
      conv.source = 'whatsapp'
    end

    users_hash = current_user.account.users.index_by(&:id)
    render json: format_conversation(conversation, users_hash), status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Revendedora não encontrada ou fora da sua carteira.' }, status: :not_found
  end

  def show
    conversation = visible_conversations_scope
      .includes(:user, :tags, messages: { attachment_attachment: :blob }, contact: { notes: :user, pedidos: {}, reseller_phones: {}, lifecycle_events: {} })
      .find(params[:id])
    users_hash = current_user.account.users.index_by(&:id)
    render json: format_conversation(conversation, users_hash)
  end

  def update
    conversation = visible_conversations_scope.includes(:tags, :contact, :inbox).find(params[:id])
    users_hash = current_user.account.users.index_by(&:id)
    old_user_id = conversation.user_id
    new_status_param = params.dig(:conversation, :status)

    if conversation.update(conversation_params)
      # Side effects por mudança de status
      if new_status_param == 'resolved'
        handle_resolve_side_effects(conversation)
      elsif new_status_param == 'open'
        conversation.update_column(:snoozed_until, nil) if conversation.snoozed_until.present?
      end

      new_user_id = conversation.user_id
      if new_user_id != old_user_id
        # Notifica o atendente que recebeu o lead
        if new_user_id.present?
          new_agent = users_hash[new_user_id]
          ActionCable.server.broadcast("conversations_channel_#{current_user.account_id}", {
            event: 'lead_atribuido',
            assigned_to_user_id: new_user_id,
            conversation_id: conversation.id,
            contact_name: conversation.contact.name.presence || conversation.contact.phone,
            assigned_by: 'manual'
          })
          AgentNotificationService.notify_assignment(
            agent:        new_agent,
            conversation: conversation.reload,
            assigned_by:  'manual'
          )
        end

        tag = current_user.account.tags.find_or_create_by!(name: 'com_atendente') { |t| t.color = '#8b5cf6' }
        if new_user_id.present?
          unless conversation.tags.any? { |t| t.id == tag.id }
            conversation.tags << tag
            conversation.tags.reset
          end
        else
          conversation.conversation_tags.where(tag_id: tag.id).delete_all
          conversation.tags.reset
        end
        ActionCable.server.broadcast("conversations_channel_#{current_user.account_id}", {
          event: 'conversation_tags_updated',
          conversation_id: conversation.id,
          tags: conversation.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
        })

        # Nota de transferência — mensagem privada visível apenas para a equipe
        if params[:transfer_note].present? && new_user_id.present?
          note_msg = Message.create!(
            account:      current_user.account,
            conversation: conversation,
            text:         "Transferido por #{current_user.first_name}: #{params[:transfer_note]}",
            sender_type:  'User',
            sender_id:    current_user.id,
            source_id:    "transfer_#{SecureRandom.hex(8)}",
            status:       :delivered,
            is_private:   true
          )
          ActionCable.server.broadcast("conversations_channel_#{current_user.account_id}", {
            event:           'message_created',
            conversation_id: conversation.id,
            message: {
              id:         note_msg.id,
              senderType: 'agent',
              text:       note_msg.text,
              timestamp:  note_msg.created_at.iso8601,
              status:     'delivered',
              agentName:  current_user.first_name,
              isPrivate:  true
            }
          })
        end
      end

      ActionCable.server.broadcast("conversations_channel_#{current_user.account_id}", {
        event: 'conversation_updated',
        conversation: format_conversation(conversation, users_hash)
      })
      render json: format_conversation(conversation, users_hash)
    else
      render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /conversations/1 — apaga só o histórico de mensagens desta
  # conversa (Message tem dependent: :destroy em Conversation). Diferente de
  # "Apagar contato": o Contact (revendedora, notas, pedidos, tags) continua
  # intacto, só a conversa some.
  def destroy
    conversation = visible_conversations_scope.find(params[:id])
    conversation.destroy!
    head :no_content
  end

  def ai_status
    conversation = visible_conversations_scope.includes(:contact).find(params[:id])
    contact_jid = conversation.contact.channel_identifier
    cache_key = "ai_paused_#{conversation.inbox_id}_#{contact_jid}"
    paused_at = Rails.cache.read(cache_key)

    if paused_at
      remaining = [(30 * 60) - (Time.current.to_i - paused_at.to_i), 0].max
      render json: { paused: true, remaining_seconds: remaining }
    else
      render json: { paused: false, remaining_seconds: 0 }
    end
  end

  def resume_ai
    conversation = visible_conversations_scope.includes(:contact, :tags).find(params[:id])
    contact_jid = conversation.contact.channel_identifier
    Rails.cache.delete("ai_paused_#{conversation.inbox_id}_#{contact_jid}")
    agente_off = conversation.tags.find { |t| t.name == 'agente_off' }
    if agente_off
      conversation.conversation_tags.where(tag_id: agente_off.id).delete_all
      remaining_tags = conversation.tags.reject { |t| t.id == agente_off.id }
      ActionCable.server.broadcast("conversations_channel_#{current_user.account_id}", {
        event: 'conversation_tags_updated',
        conversation_id: conversation.id,
        tags: remaining_tags.map { |t| { id: t.id, name: t.name, color: t.color } }
      })
    end
    render json: { success: true }
  end

  def generate_summary
    conversation = visible_conversations_scope.includes(:messages).find(params[:id])
    
    recent_messages = conversation.messages.order(created_at: :asc).last(30)
    
    chat_history = recent_messages.map do |msg|
      "#{msg.sender_type == 'Contact' ? 'Cliente' : 'Corretor/IA'}: #{msg.text || '[Mídia]'}"
    end.join("\n")

    system_prompt = <<~PROMPT
      Você é um assistente de imobiliária. Seu objetivo é ler o histórico da conversa abaixo e gerar um resumo curto, direto e objetivo do atendimento.
      Destaque as principais informações como:
      - O que o cliente busca (imóvel/perfil)
      - Faixa de valor
      - Região de interesse
      - Próximos passos combinados
      Não crie informações que não estejam no texto. Retorne apenas o resumo.
    PROMPT

    begin
      api_key = GlobalSetting.fetch('openai_api_key').presence || ENV['OPENAI_API_KEY']
      client = OpenAI::Client.new(access_token: api_key)
      
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: "Histórico:\n#{chat_history}" }
          ],
          temperature: 0.3
        }
      )
      
      summary = response.dig("choices", 0, "message", "content")
      render json: { summary: summary }
    rescue StandardError => e
      Rails.logger.error("Error generating summary: \#{e.message}")
      render json: { error: "Erro ao gerar resumo." }, status: :unprocessable_entity
    end
  end

  def transcript
    conversation = visible_conversations_scope
      .includes(messages: :attachment_attachment, contact: {})
      .find(params[:id])

    contact = conversation.contact
    messages = conversation.messages.order(:created_at)
    account_name = current_user.account.name rescue 'Imobiliária'

    lines = []
    lines << "=" * 60
    lines << "TRANSCRIÇÃO DA CONVERSA"
    lines << "=" * 60
    lines << "Imobiliária: #{account_name}"
    lines << "Contato: #{contact.name.presence || contact.phone}"
    lines << "Telefone: #{contact.phone}"
    lines << "Atendente: #{conversation.user&.first_name || 'Não atribuído'}"
    lines << "Data: #{I18n.l(Time.current, format: '%d/%m/%Y %H:%M')}"
    lines << "=" * 60
    lines << ""

    messages.each do |msg|
      next if msg.text.blank? && msg.attachment.blank?
      time   = msg.created_at.strftime('%d/%m/%Y %H:%M')
      author = msg.sender_type == 'Contact' ? (contact.name.presence || 'Lead') : 'Atendente/IA'
      text   = msg.text.presence || '[Anexo]'
      lines << "[#{time}] #{author}: #{text}"
    end

    lines << ""
    lines << "=" * 60
    lines << "Fim da transcrição — #{account_name}"
    lines << "=" * 60

    filename = "transcricao_#{contact.phone}_#{Date.current}.txt"
    send_data lines.join("\n"),
      filename: filename,
      type: 'text/plain; charset=utf-8',
      disposition: 'attachment'
  end

  private

  # Prioriza uma caixa de WhatsApp que o usuário tem acesso (InboxMembers);
  # sem nenhuma específica, usa a primeira caixa Baileys conectada da conta
  # (caso comum: só existe uma linha de WhatsApp na empresa toda).
  def pick_inbox_for(_contact)
    current_user.assigned_inboxes.where(provider: 'baileys').first ||
      current_user.account.inboxes.where(provider: 'baileys').first
  end

  # Mesma lógica de ContactsController#visible_contacts_scope — consultor só
  # acessa conversa atribuída a ele, mesmo sabendo o ID direto (antes todo
  # action aqui buscava só por account_id, sem checar dono).
  def visible_conversations_scope
    base = current_user.account.conversations
    if full_portfolio? || finance? || current_user.has_permission?('admin')
      base
    else
      lider_ids = current_user.accessible_jueri_lider_ids
      if lider_ids.any?
        base.left_joins(:contact).where(
          "conversations.user_id = :uid OR contacts.custom_attributes ->> 'gerente_jueri_id' IN (:lider_ids)",
          uid: current_user.id, lider_ids: lider_ids
        )
      else
        base.where(user_id: current_user.id)
      end
    end
  end

  def conversation_params
    params.require(:conversation).permit(:status, :user_id, :snoozed_until)
  end

  def format_conversation(conv, users_hash = {})
    # Sort in memory — avoids N+1 from .order() on eager-loaded association
    sorted_messages = conv.messages.sort_by(&:created_at)
    last_message = sorted_messages.last
    sorted_notes = conv.contact.notes.sort_by { |n| -n.created_at.to_i }

    {
      id: conv.id,
      contact: {
        id: conv.contact.id,
        name: conv.contact.name,
        email: conv.contact.email,
        phone: conv.contact.phone,
        jid: conv.contact.jid,
        avatar_url: conv.contact.avatar_url,
        avatarInitials: conv.contact.name.to_s[0..1].upcase,
        avatarBg: '#d49ba7',
        status: conv.contact.status,
        id_jueri: conv.contact.id_jueri,
        cpf: conv.contact.cpf,
        birth_date: conv.contact.birth_date,
        bio: conv.contact.bio,
        company_name: conv.contact.company_name,
        country: conv.contact.country,
        city: conv.contact.city,
        cep: conv.contact.cep,
        street: conv.contact.street,
        neighborhood: conv.contact.neighborhood,
        state: conv.contact.state,
        address_number: conv.contact.address_number,
        address_complement: conv.contact.address_complement,
        custom_attributes: conv.contact.custom_attributes,
        pecas_abertas_atual: conv.contact.pecas_abertas_atual,
        pedidos: conv.contact.pedidos.map do |p|
          {
            id: p.id, jueri_pedido_id: p.jueri_pedido_id,
            data_criacao: p.data_criacao, data_baixa: p.data_baixa, data_cancelamento: p.data_cancelamento,
            quantidade: p.quantidade, valor_total: p.valor_total, status_id: p.status_id
          }
        end,
        reseller_phones: conv.contact.reseller_phones.map { |rp| { id: rp.id, phone: rp.phone, label: rp.label } },
        lifecycle_events: conv.contact.lifecycle_events.sort_by(&:occurred_at).reverse.map { |e|
          { id: e.id, event_type: e.event_type, occurred_at: e.occurred_at, metadata: e.metadata }
        },
        notes: sorted_notes.map do |n|
          {
            id: n.id,
            content: n.content,
            created_at: n.created_at,
            author: n.user&.first_name || 'Sistema'
          }
        end
      },
      inbox_id: conv.inbox_id,
      source: conv.source || 'whatsapp',
      preview: last_message&.text || 'Nova Conversa',
      timestamp: last_message ? last_message.created_at.strftime('%H:%M') : conv.created_at.strftime('%H:%M'),
      # timestamp acima é só "HH:MM" pra exibir na lista — não dá pra ordenar
      # por ele (new Date("14:08") vira Invalid Date, todo mundo "empatado",
      # é por isso que o botão Ordenar parecia não fazer nada). Esse aqui é
      # o valor de verdade que a store usa pra ordenar.
      last_activity_iso: (last_message&.created_at || conv.last_activity_at || conv.created_at).iso8601,
      unread: conv.unread_count,
      messages: sorted_messages.map do |msg|
        sender_type = msg.sender_type.downcase
        {
          id: msg.id,
          senderType: sender_type == 'user' ? 'agent' : sender_type,
          text: msg.text,
          timestamp: msg.created_at.iso8601,
          status: msg.status,
          agentName: msg.sender_type == 'User' ? (users_hash[msg.sender_id]&.first_name || 'Agente') : nil,
          agentAvatarUrl: msg.sender_type == 'User' ? users_hash[msg.sender_id]&.avatar_url : nil,
          isPrivate: msg.is_private,
          attachmentUrl: msg.attachment.attached? ? Rails.application.routes.url_helpers.rails_storage_proxy_url(msg.attachment, host: ENV['API_HOST'] || 'http://localhost:3000') : nil,
          attachmentType: msg.attachment.attached? ? msg.attachment.content_type : nil
        }
      end,
      assignee: conv.user&.first_name,
      assignee_id: conv.user_id,
      status: conv.status,
      snoozed_until: conv.snoozed_until,
      tags: conv.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
    }
  end

  def handle_resolve_side_effects(conversation)
    contact = conversation.contact
    inbox   = conversation.inbox

    # Pausa a IA por 30 dias (permanente para fins práticos)
    jid = contact.channel_identifier
    if jid.present? && inbox.present?
      Rails.cache.write("ai_paused_#{inbox.id}_#{jid}", Time.current.to_i, expires_in: 30.days)
    end

    # Aplica tag agente_off
    tag = conversation.account.tags.find_or_create_by!(name: 'agente_off') { |t| t.color = '#f97316' }
    unless conversation.tags.any? { |t| t.id == tag.id }
      conversation.tags << tag
    end

    # Move o lead no kanban
    kanban_stage = params[:kanban_stage].presence
    contact.update!(status: kanban_stage) if kanban_stage.present?

    # Envia mensagem de encerramento
    if params[:send_closing_message].to_s == 'true' && params[:closing_message_text].present?
      begin
        recipient = contact.channel_identifier
        baileys_id = inbox.messaging_service.send_message(recipient, params[:closing_message_text]) if inbox.present? && recipient.present?
        closing_msg = Message.create!(
          account:     conversation.account,
          conversation: conversation,
          text:        params[:closing_message_text],
          sender_type: 'User',
          sender_id:   current_user.id,
          source_id:   baileys_id.presence || "closing_#{SecureRandom.hex(8)}",
          status:      :delivered
        )
        ActionCable.server.broadcast("conversations_channel_#{current_user.account_id}", {
          event:           'message_created',
          conversation_id: conversation.id,
          message: {
            id:         closing_msg.id,
            senderType: 'agent',
            text:       closing_msg.text,
            timestamp:  closing_msg.created_at.iso8601,
            status:     'delivered',
            agentName:  current_user.first_name,
            agentAvatarUrl: current_user.avatar_url
          }
        })
      rescue => e
        Rails.logger.error("Erro ao enviar mensagem de encerramento: #{e.message}")
      end
    end

    # Broadcast das tags atualizadas
    updated_tags = conversation.tags.reload.map { |t| { id: t.id, name: t.name, color: t.color } }
    ActionCable.server.broadcast("conversations_channel_#{current_user.account_id}", {
      event:           'conversation_tags_updated',
      conversation_id: conversation.id,
      tags:            updated_tags
    })
  end
end
