# Roda periodicamente pra puxar revendedoras ativas do Jueri (briefing seções 25,
# 29.1-29.2). Não derruba o loop se o Jueri estiver fora do ar ou com rate limit —
# só loga e tenta de novo no próximo ciclo.
#
# INCIDENTE 2026-09-01: até aqui esse job (e ReguaAutoAdvanceJob/
# CheckSnoozedConversationsJob) se auto-reagendava (ensure + perform_later) E
# era relançado de novo a cada boot do backend/worker (config/initializers/
# recurring_jobs.rb) — cada deploy empilhava mais uma corrente recorrente
# paralela, sem nunca desligar as antigas. O lock por cache (Rails.cache,
# unless_exist) NÃO protegia de verdade: como ele era liberado no ensure logo
# depois de cada tentativa (~300ms), qualquer uma das centenas de correntes
# acumuladas conseguia o lock livre a qualquer momento e batia na API do
# Jueri — daí a cascata de 429 "Too Many Attempts" quase contínua, comendo
# a capacidade do worker inteira e atrasando todo o resto (mensagem
# agendada, follow-up de IA, gatilhos com atraso). Migrado pro Recorrente
# nativo do Solid Queue (config/recurring.yml) — mesmo padrão já usado pelo
# AiFollowupJob, que nunca teve esse problema: agendamento único e
# deduplicado por definição, não duplica em boot nenhum. As correntes
# antigas (esse deploy tira o auto-reagendamento) disparam mais uma vez cada
# uma, dentro da janela de intervalo que já tinham, e somem sozinhas.
class JueriSyncJob < ApplicationJob
  queue_as :default

  # account_id presente = disparo pontual (ex: webhook do Jueri, POST /jueri/sync-now).
  def perform(account_id = nil)
    return unless JueriApiService.configured?

    scope = account_id ? Account.where(id: account_id) : Account.all

    scope.find_each do |account|
      resultado = JueriSyncService.new(account: account).call
      Rails.logger.info("[JueriSyncJob] account=#{account.id} criados=#{resultado[:criados]} reativados=#{resultado[:reativados]} atualizados=#{resultado[:atualizados]} erros=#{resultado[:erros]}")
    rescue JueriApiService::ApiError => e
      Rails.logger.error("[JueriSyncJob] account=#{account.id} falhou: #{e.message}")
    end
  end
end
