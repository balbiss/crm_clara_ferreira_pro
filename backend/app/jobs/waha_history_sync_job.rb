# Importa do WhatsApp as mensagens que não chegaram pelo webhook: tudo que foi
# conversado pelo celular enquanto a caixa estava deslogada/caída, ou que se
# perdeu num restart da WAHA/servidor. Antes disso o CRM só tinha o que
# chegava ao vivo, então qualquer queda virava buraco permanente no histórico
# (dona pediu, 2026-10-01: "no Kommo a gente não perde o histórico").
# Medido antes de existir: 181 mensagens faltando em só 3 dias, 71 numa caixa só.
#
# Dois jeitos de rodar:
# - perform(inbox_id, since_epoch): disparado quando a caixa volta a ficar
#   WORKING (ver Webhooks::WahaController#handle_session_status), cobrindo
#   desde a última mensagem que o CRM tinha antes da queda.
# - perform() sem argumento: recorrente (config/recurring.yml), rede de
#   segurança pras últimas horas de todas as caixas conectadas.
class WahaHistorySyncJob < ApplicationJob
  include WahaMessageIngestion

  queue_as :default

  RECURRING_LOOKBACK = 3.hours
  MAX_LOOKBACK = 7.days

  def perform(inbox_id = nil, since_epoch = nil)
    inboxes = inbox_id ? Inbox.where(id: inbox_id, provider: 'waha') : Inbox.where(provider: 'waha')
    since = since_epoch ? Time.zone.at(since_epoch.to_i) : RECURRING_LOOKBACK.ago
    since = [since, MAX_LOOKBACK.ago].max

    inboxes.find_each { |inbox| sync_inbox(inbox, since) }
  end

  # Usado pelo webhook na reconexão: a partir de quando buscar.
  def self.since_for(inbox)
    last = Message.joins(:conversation).where(conversations: { inbox_id: inbox.id }).maximum(:created_at)
    last ? last - 1.hour : MAX_LOOKBACK.ago
  end

  private

  def sync_inbox(inbox, since)
    service = WhatsappWahaService.new(inbox)
    return unless service.connected?

    imported = 0
    chats = service.fetch_recent_chats
    chats.each do |chat|
      break if chat['timestamp'].to_i < since.to_i # lista vem do mais recente pro mais antigo

      chat_id = chat.dig('id', '_serialized') || chat['id'].to_s
      next if chat_id.blank? || chat_id == 'status@broadcast'

      imported += sync_chat(inbox, service, chat_id, since)
    rescue => e
      Rails.logger.error("[WahaHistorySync] inbox #{inbox.id} chat #{chat_id}: #{e.message}")
    end

    Rails.logger.info("[WahaHistorySync] inbox #{inbox.id} (#{inbox.name}) desde #{since}: #{imported} mensagens importadas")
    imported
  end

  def sync_chat(inbox, service, chat_id, since)
    messages = service.fetch_chat_messages(chat_id, since: since)
    missing = messages.map(&:with_indifferent_access)
                      .select { |m| m[:timestamp].to_i >= since.to_i }
                      .reject { |m| m[:body].to_s.blank? && !m[:hasMedia] } # aviso de sistema/chamada, nunca vira mensagem
                      .reject { |m| already_imported?(inbox, m) }
    return 0 if missing.empty?

    # Só pede pra WAHA baixar mídia quando realmente falta alguma mensagem
    # com anexo — baixar sempre faria ela puxar todos os arquivos do chat a
    # cada rodada, inclusive os que o CRM já tem.
    if missing.any? { |m| m[:hasMedia] }
      with_media = service.fetch_chat_messages(chat_id, since: since, download_media: true)
                          .map(&:with_indifferent_access).index_by { |m| m[:id] }
      missing = missing.map { |m| with_media[m[:id]] || m }
    end

    missing.sort_by { |m| m[:timestamp].to_i }.count do |payload|
      handle_message(inbox, payload, historical: true).present?
    rescue => e
      Rails.logger.error("[WahaHistorySync] mensagem #{payload[:id]}: #{e.message}")
      false
    end
  end
end
