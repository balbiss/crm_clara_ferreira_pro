# Roda periodicamente pra puxar revendedoras ativas do Jueri (briefing seções 25,
# 29.1-29.2). Mesmo padrão auto-perpetuante do ReguaAutoAdvanceJob/
# CheckSnoozedConversationsJob. Não derruba o loop se o Jueri estiver fora do ar ou
# com rate limit — só loga e tenta de novo no próximo ciclo.
class JueriSyncJob < ApplicationJob
  queue_as :default

  INTERVALO_MINUTOS = ENV.fetch('JUERI_SYNC_INTERVAL_MINUTES', 30).to_i
  LOCK_KEY = 'jueri_sync_job_lock'

  # account_id presente = disparo pontual (ex: webhook do Jueri, POST /jueri/sync-now)
  # e não reagenda o loop recorrente; account_id ausente = execução do loop principal,
  # que sempre reagenda a próxima rodada.
  def perform(account_id = nil)
    return unless JueriApiService.configured?

    if account_id.nil? && !adquirir_lock_recorrente
      # config/initializers/recurring_jobs.rb agenda um novo início de corrente a
      # CADA boot do backend/worker, sem checar se já existe uma rodando — depois
      # de vários deploys seguidos isso empilha múltiplas correntes recorrentes em
      # paralelo, martelando a API do Jueri e disparando 429 em cascata (mesma
      # classe do incidente do JueriReconciliarPedidosAbertosJob). Esse lock
      # colapsa todas as correntes duplicadas pra só uma rodar de verdade por vez;
      # as outras só pulam esse ciclo e tentam de novo depois.
      Rails.logger.info('[JueriSyncJob] já existe uma sincronização recorrente em andamento (corrente duplicada de outro boot) — pulando esse ciclo')
      self.class.set(wait: INTERVALO_MINUTOS.minutes).perform_later
      return
    end

    scope = account_id ? Account.where(id: account_id) : Account.all

    scope.find_each do |account|
      resultado = JueriSyncService.new(account: account).call
      Rails.logger.info("[JueriSyncJob] account=#{account.id} criados=#{resultado[:criados]} reativados=#{resultado[:reativados]} atualizados=#{resultado[:atualizados]} erros=#{resultado[:erros]}")
    rescue JueriApiService::ApiError => e
      Rails.logger.error("[JueriSyncJob] account=#{account.id} falhou: #{e.message}")
    end
  ensure
    if account_id.nil?
      Rails.cache.delete(LOCK_KEY)
      self.class.set(wait: INTERVALO_MINUTOS.minutes).perform_later
    end
  end

  private

  def adquirir_lock_recorrente
    # expires_in é rede de segurança: se o processo cair no meio do sync sem
    # passar pelo ensure, o lock não fica preso pra sempre.
    Rails.cache.write(LOCK_KEY, true, unless_exist: true, expires_in: INTERVALO_MINUTOS.minutes)
  end
end
