require_relative '../services/whatsapp_baileys_service'

class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    conversation = current_user.account.conversations.find(params[:conversation_id])
    
    is_private_msg = params[:is_private].to_s == 'true'

    # Caixa com WhatsApp caído: antes gravava e mostrava "enviada" mesmo sem
    # sair nada (Clara, 2026-10-15: Comercial-Consultores em SCAN_QR e a
    # equipe mandando sem saber). Só bloqueia com status ruim CONFIRMADO pela
    # WAHA — se ela não responder, segue o envio normal.
    if !is_private_msg && (motivo = caixa_desconectada(conversation.inbox))
      return render json: { error: 'caixa_desconectada', message: motivo }, status: :unprocessable_entity
    end

    # Clique repetido na MESMA mensagem (o front manda o mesmo client_msg_id
    # ao tentar de novo): com o WhatsApp lento o 1º envio ainda está rodando
    # quando o navegador desiste ("Sem resposta do servidor"), a pessoa clica
    # de novo e a revendedora recebia a mensagem duplicada.
    client_key = params[:client_msg_id].present? ? "client_msg_#{conversation.id}_#{params[:client_msg_id].to_s[0, 64]}" : nil
    if client_key && (anterior = Rails.cache.read(client_key))
      existente = conversation.messages.find_by(id: anterior) if anterior.is_a?(Integer)
      if existente
        return render json: { success: true, duplicate: true, message: message_json(existente) }, status: :ok
      end
      return render json: { error: 'envio_em_andamento', message: 'Essa mensagem ainda está sendo enviada, aguarde alguns segundos.' }, status: :conflict
    end
    Rails.cache.write(client_key, 'pending', expires_in: 10.minutes) if client_key

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
    elsif params[:forward_message_id].present?
      # Encaminhar: copia o anexo (áudio/foto/documento) de uma mensagem já
      # existente da conta. Cópia e não o mesmo blob, pra apagar uma conversa
      # nunca levar junto o arquivo da outra.
      source = Message.where(account_id: current_user.account_id).find(params[:forward_message_id])
      if source.attachment.attached?
        message.attachment.attach(
          io: StringIO.new(source.attachment.download),
          filename: source.attachment.filename.to_s,
          content_type: source.attachment.content_type
        )
      end
    end

    begin
      saved = message.save
    rescue StandardError => e
      # Falha ao gravar o anexo (storage) virava 500 sem explicação nenhuma
      # na tela — agora o motivo chega no aviso de erro do chat.
      Rails.logger.error("Falha ao salvar mensagem/anexo na conversa #{conversation.id}: #{e.class} #{e.message}")
      Rails.cache.delete(client_key) if client_key
      return render json: { error: 'falha_anexo', message: "Não foi possível salvar o anexo (#{e.class.name.demodulize})." }, status: :unprocessable_entity
    end

    if saved
      Rails.cache.write(client_key, message.id, expires_in: 10.minutes) if client_key
      if !is_private_msg && %w[baileys waha instagram].include?(conversation.inbox&.provider)
        begin
          recipient = conversation.contact.channel_identifier
          # Flag de curta duração ANTES de mandar pra API — o eco (fromMe:
          # true) do webhook pode chegar e ser processado antes da resposta
          # do send_message voltar aqui (visto ao vivo: com o backend
          # rápido, o webhook ganha a corrida do source_id quase toda vez).
          # Sem essa flag, o eco não acha o Message (source_id ainda nil) e
          # cria uma SEGUNDA mensagem duplicada. Mesmo padrão do
          # ai_is_replying_* já usado pro eco da IA, agora pro envio manual.
          chat_id = conversation.contact.jid
          Rails.cache.write("sending_from_crm_#{conversation.inbox.id}_#{chat_id}", true, expires_in: 20.seconds) if chat_id.present?

          external_id = conversation.inbox.messaging_service.send_message(recipient, signed_text(conversation.inbox, message.text), message.attachment)
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

      render json: { success: true, message: message_json(message) }, status: :created
    else
      Rails.cache.delete(client_key) if client_key
      render json: { errors: message.errors }, status: :unprocessable_entity
    end
  end

  # Botão "T" ao lado do áudio no chat: transcreve sob demanda e guarda em
  # messages.transcription (o text original não é tocado). Se já foi
  # transcrito, devolve o salvo sem chamar a OpenAI de novo.
  def transcribe
    conversation = current_user.account.conversations.find(params[:conversation_id])
    message = conversation.messages.find(params[:id])

    if message.transcription.present?
      return render json: { transcription: message.transcription }
    end

    unless message.attachment.attached? && message.attachment.content_type.to_s.start_with?('audio/')
      return render json: { error: 'Essa mensagem não tem áudio.' }, status: :unprocessable_entity
    end

    if AiAssistantService.transcription_api_key.blank?
      return render json: { error: 'Transcrição indisponível: chave da IA não configurada.' }, status: :unprocessable_entity
    end

    extension = message.attachment.filename.extension.presence ||
                message.attachment.content_type.split('/').last.split(';').first
    text = AiAssistantService.transcribe_audio(message.attachment.download, "audio_#{message.id}.#{extension}", conversation.inbox)

    if text.blank?
      return render json: { error: 'Não foi possível entender o áudio.' }, status: :unprocessable_entity
    end

    message.update_column(:transcription, text.strip)
    render json: { transcription: message.transcription }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Mensagem não encontrada.' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error("Falha ao transcrever mensagem #{params[:id]}: #{e.class} #{e.message}")
    render json: { error: 'Falha ao transcrever o áudio. Tente de novo.' }, status: :unprocessable_entity
  end

  private

  def message_json(message)
    {
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
    }
  end

  STATUS_WAHA_DESCONECTADO = %w[SCAN_QR_CODE FAILED STOPPED].freeze

  # Mensagem de erro se a caixa estiver comprovadamente desconectada, nil
  # caso contrário (inclusive se a WAHA não responder). Cache curto pra não
  # consultar a WAHA a cada mensagem de uma conversa movimentada.
  def caixa_desconectada(inbox)
    return nil unless inbox&.provider == 'waha'

    status = Rails.cache.fetch("waha_status_#{inbox.id}", expires_in: 15.seconds, skip_nil: true) do
      inbox.messaging_service.session_status
    end
    return nil unless STATUS_WAHA_DESCONECTADO.include?(status)

    "O WhatsApp \"#{inbox.name}\" está desconectado, a mensagem NÃO foi enviada. Reconecte em Configurações → Caixas de Entrada."
  end

  # Assinatura com o nome de quem respondeu (chave "Assinar mensagens" da
  # caixa). Só vai pro WhatsApp/Instagram — no banco e no chat do CRM o texto
  # fica limpo. Sem texto (áudio/anexo sem legenda) não assina.
  def signed_text(inbox, text)
    return text unless inbox.sign_messages && text.to_s.strip.present?

    name = current_user.first_name.to_s.strip
    return text if name.blank?

    # Instagram não formata *negrito*, sairia com os asteriscos.
    header = inbox.provider == 'instagram' ? "#{name}:" : "*#{name}:*"
    "#{header}\n#{text}"
  end
end
