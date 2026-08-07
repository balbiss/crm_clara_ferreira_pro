# Chat interno da equipe — qualquer usuário autenticado pode conversar com
# qualquer outro da MESMA conta (consultor fala com financeiro, com gerente,
# com diretoria, sem restrição de papel: é justamente pra isso que serve).
# Sem relação com WhatsApp/Conversation — ver InternalMessage.
class InternalMessagesController < ApplicationController
  before_action :authenticate_user!

  # GET /internal_messages/threads — um "colega" por linha, com prévia da
  # última mensagem e quantas estão sem ler, ordenado por atividade recente.
  def threads
    colleagues = current_user.account.users.where.not(id: current_user.id)

    last_by_colleague = {}
    InternalMessage.where(account_id: current_user.account_id)
                    .where('sender_id = :me OR recipient_id = :me', me: current_user.id)
                    .order(created_at: :desc)
                    .each do |m|
      other_id = m.sender_id == current_user.id ? m.recipient_id : m.sender_id
      last_by_colleague[other_id] ||= m
    end

    unread_by_colleague = InternalMessage
      .where(account_id: current_user.account_id, recipient_id: current_user.id, read_at: nil)
      .group(:sender_id).count

    threads = colleagues.map do |u|
      last = last_by_colleague[u.id]
      {
        id: u.id,
        first_name: u.first_name,
        last_name: u.last_name,
        role: u.role,
        last_message: last && message_preview(last),
        last_message_at: last&.created_at,
        unread_count: unread_by_colleague[u.id] || 0
      }
    end

    render json: threads.sort_by { |t| t[:last_message_at] ? -t[:last_message_at].to_i : 0 }
  end

  # GET /internal_messages?with=<user_id> — histórico com um colega
  # específico. Marca como lidas as que estavam pendentes pra mim.
  def index
    other = current_user.account.users.find(params[:with])

    messages = InternalMessage.between(current_user.id, other.id).order(:created_at)

    InternalMessage.where(account_id: current_user.account_id, sender_id: other.id,
                           recipient_id: current_user.id, read_at: nil)
                    .update_all(read_at: Time.current)

    render json: messages.map { |m| serialize(m) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Usuário não encontrado.' }, status: :not_found
  end

  # POST /internal_messages { recipient_id, text, attachment }
  # text é opcional quando vem attachment (áudio gravado na hora, foto,
  # documento) — precisa de pelo menos um dos dois, ver validação no model.
  def create
    recipient = current_user.account.users.find(params[:recipient_id])
    message = InternalMessage.new(
      account: current_user.account,
      sender: current_user,
      recipient: recipient,
      text: params[:text].presence
    )
    message.attachment.attach(params[:attachment]) if params[:attachment].present?
    message.save!

    ActionCable.server.broadcast("internal_chat_channel_#{current_user.account_id}", {
      event: 'internal_message_created',
      message: serialize(message)
    })

    render json: serialize(message), status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Usuário não encontrado.' }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  # Prévia pra lista de conversas quando a última mensagem é só anexo (sem
  # texto) — senão ficava em branco na listagem.
  def message_preview(m)
    return m.text if m.text.present?
    return nil unless m.attachment.attached?

    type = m.attachment.content_type.to_s
    if type.start_with?('image/')
      '📷 Foto'
    elsif type.start_with?('audio/')
      '🎤 Áudio'
    else
      "📎 #{m.attachment.filename}"
    end
  end

  def serialize(m)
    {
      id: m.id,
      sender_id: m.sender_id,
      recipient_id: m.recipient_id,
      text: m.text,
      created_at: m.created_at,
      read_at: m.read_at,
      attachment_url: m.attachment.attached? ? Rails.application.routes.url_helpers.rails_blob_url(m.attachment, host: ENV['API_HOST'] || 'http://localhost:3000') : nil,
      attachment_type: m.attachment.attached? ? m.attachment.content_type : nil,
      attachment_name: m.attachment.attached? ? m.attachment.filename.to_s : nil
    }
  end
end
