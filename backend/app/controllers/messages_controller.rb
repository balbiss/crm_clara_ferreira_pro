require_relative '../services/whatsapp_baileys_service'

class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    conversation = current_user.account.conversations.find(params[:conversation_id])
    
    is_private_msg = params[:is_private].to_s == 'true'

    message = conversation.messages.build(
      account: current_user.account,
      sender_type: 'User',
      sender_id: current_user.id,
      text: params[:text] || '',
      is_private: is_private_msg,
      status: :sent
    )
    
    if params[:attachment].present?
      message.attachment.attach(params[:attachment])
    end

    if message.save
      if !is_private_msg && %w[baileys waha instagram].include?(conversation.inbox&.provider)
        begin
          recipient = conversation.contact.channel_identifier
          external_id = conversation.inbox.messaging_service.send_message(recipient, message.text, message.attachment)
          # Guarda o id retornado pela API como source_id — sem isso o eco
          # dessa mesma mensagem (fromMe: true) que chega depois pelo webhook
          # não encontra nenhum Message correspondente, e é tratado como
          # intervenção humana via celular: cria uma SEGUNDA mensagem
          # duplicada (sem sender_id, avatar genérico) e ainda pausa a IA à toa.
          message.update_column(:source_id, external_id) if external_id.present?
        rescue StandardError => e
          Rails.logger.error("Failed to send message via #{conversation.inbox.provider}: #{e.message}")
        end
      end

      # Optionally render just the new message, but we can also just return success
      render json: { success: true, message: {
        id: message.id,
        senderType: 'agent',
        text: message.text,
        timestamp: message.created_at.strftime('%H:%M'),
        status: message.status,
        agentName: current_user.first_name,
        agentAvatarUrl: current_user.avatar_url,
        isPrivate: message.is_private,
        attachmentUrl: message.attachment.attached? ? Rails.application.routes.url_helpers.rails_storage_proxy_url(message.attachment, host: ENV['API_HOST'] || 'http://localhost:3000') : nil,
        attachmentType: message.attachment.attached? ? message.attachment.content_type : nil,
        attachmentName: message.attachment.attached? ? message.attachment.filename.to_s : nil
      }}, status: :created
    else
      render json: { errors: message.errors }, status: :unprocessable_entity
    end
  end
end
