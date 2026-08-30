# Fast path do webhook do Jueri: aplica só o pedido do próprio evento
# (JueriSyncService#sync_pedido_evento) e recalcula o snapshot da revendedora
# afetada em milissegundos, sem esperar o JueriSyncJob completo (~157s,
# histórico inteiro paginado) — que continua rodando em paralelo, debounced,
# como rede de segurança pros casos que este fast path não cobre.
class JueriWebhookPedidoJob < ApplicationJob
  queue_as :default

  def perform(account_id, jueri_payload, evento = nil)
    return unless JueriApiService.configured?

    account = Account.find_by(id: account_id)
    return unless account

    service = JueriSyncService.new(account: account)
    # pedido.deleted precisa de tratamento dedicado (marca Cancelado em vez
    # de upsert genérico) — o payload de exclusão não traz status confiável
    # pra distinguir de um pedido.created/updated normal.
    resultado = evento == 'pedido.deleted' ? service.sync_pedido_excluido(jueri_payload) : service.sync_pedido_evento(jueri_payload)
    Rails.logger.info("[JueriWebhookPedidoJob] account=#{account.id} evento=#{evento.inspect} pedido=#{jueri_payload['id'] || jueri_payload[:id]} #{resultado}")
  rescue JueriApiService::ApiError => e
    Rails.logger.error("[JueriWebhookPedidoJob] account=#{account_id} falhou: #{e.message}")
  end
end
