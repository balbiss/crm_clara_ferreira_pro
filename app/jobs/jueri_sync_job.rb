# Roda periodicamente pra puxar revendedoras ativas do Jueri (briefing seções 25,
# 29.1-29.2). Mesmo padrão auto-perpetuante do ReguaAutoAdvanceJob/
# CheckSnoozedConversationsJob. Não derruba o loop se o Jueri estiver fora do ar ou
# com rate limit — só loga e tenta de novo no próximo ciclo.
class JueriSyncJob < ApplicationJob
  queue_as :default

  INTERVALO_MINUTOS = ENV.fetch('JUERI_SYNC_INTERVAL_MINUTES', 30).to_i

  # account_id presente = disparo pontual (ex: webhook do Jueri) e não reagenda o loop
  # recorrente; account_id ausente = execução do loop principal, que sempre reagenda a
  # próxima rodada.
  def perform(account_id = nil)
    return unless JueriApiService.configured?

    scope = account_id ? Account.where(id: account_id) : Account.all

    scope.find_each do |account|
      resultado = JueriSyncService.new(account: account).call
      Rails.logger.info("[JueriSyncJob] account=#{account.id} criados=#{resultado[:criados]} reativados=#{resultado[:reativados]} atualizados=#{resultado[:atualizados]} erros=#{resultado[:erros]}")
    rescue JueriApiService::ApiError => e
      Rails.logger.error("[JueriSyncJob] account=#{account.id} falhou: #{e.message}")
    end
  ensure
    self.class.set(wait: INTERVALO_MINUTOS.minutes).perform_later if account_id.nil?
  end
end
