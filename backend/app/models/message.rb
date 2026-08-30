class Message < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  has_one_attached :attachment

  enum :status, { sent: 0, delivered: 1, read: 2, failed: 3 }
  
  # sender_type will be 'User' or 'Contact'
  # sender_id will be the id of the User or Contact

  after_create_commit :broadcast_to_conversation
  after_create_commit :update_conversation_activity
  after_create_commit :notify_agent_of_new_message

  # Reenvia o broadcast depois que texto/anexo terminam de ser processados.
  # Necessário pro webhook do Baileys: a mensagem é criada (e já dispara o
  # primeiro broadcast, sem anexo) antes da mídia terminar de baixar e ser
  # anexada — sem isso, a imagem/áudio só aparecia pro usuário depois de
  # recarregar a página, nunca em tempo real.
  def rebroadcast
    broadcast_to_conversation
  end

  private

  def update_conversation_activity
    conversation.update_column(:last_activity_at, Time.current)
  end

  def notify_agent_of_new_message
    return unless sender_type == 'Contact'
    return if is_private

    agent = conversation.user
    return unless agent

    contact = conversation.contact
    name = contact&.name.presence || contact&.phone.presence || 'Novo contato'
    body_text = text.presence || (attachment.attached? ? 'Enviou um anexo' : 'Nova mensagem')

    WebPushService.notify(
      agent,
      title: "Nova mensagem de #{name}",
      body:  body_text.truncate(120),
      url:   '/conversas',
      tag:   "conversation-#{conversation_id}"
    )
  rescue => e
    Rails.logger.error("Message push notification error: #{e.message}")
  end

  def broadcast_to_conversation
    message_payload = {
      id: id,
      senderType: sender_type.downcase == 'user' ? 'agent' : 'contact',
      text: text,
      timestamp: created_at.iso8601,
      status: status,
      agentName: sender_type == 'User' ? User.where(id: sender_id).pick(:first_name) : nil,
      agentAvatarUrl: sender_type == 'User' && sender_id.present? ? User.find_by(id: sender_id)&.avatar_url : nil,
      isPrivate: is_private,
      attachmentUrl: attachment.attached? ? Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment, host: ENV['API_HOST'] || 'http://localhost:3000') : nil,
      attachmentType: attachment.attached? ? attachment.content_type : nil
    }

    ActionCable.server.broadcast("conversations_channel_#{account_id}", {
      event: 'message_created',
      conversation_id: conversation_id,
      message: message_payload
    })
  end
end
