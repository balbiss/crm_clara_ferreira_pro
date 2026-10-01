module Webhooks
  class WahaController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false
    include WahaMessageIngestion

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

      # Voltou a conectar (reconexão por QR, restart da WAHA/servidor): importa
      # o que foi conversado pelo celular enquanto o CRM não recebia nada.
      # "since" é calculado AGORA, antes de chegarem mensagens novas ao vivo
      # (senão o buraco ficaria escondido atrás delas). Duas rodadas porque o
      # WhatsApp leva um tempo pra sincronizar o histórico no aparelho recém-
      # conectado; a deduplicação garante que a segunda não repete nada. O
      # lock evita rajada de jobs quando a WAHA manda vários WORKING seguidos.
      lock_key = "waha_history_sync_lock_#{inbox.id}"
      if status == 'WORKING' && !Rails.cache.exist?(lock_key)
        Rails.cache.write(lock_key, true, expires_in: 10.minutes)
        since = WahaHistorySyncJob.since_for(inbox).to_i
        WahaHistorySyncJob.set(wait: 1.minute).perform_later(inbox.id, since)
        WahaHistorySyncJob.set(wait: 5.minutes).perform_later(inbox.id, since)
      end
    end
  end
end
