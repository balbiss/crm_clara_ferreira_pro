# Varredura de limpeza (2026-08-30) — confere, um por um, se cada Pedido
# marcado "Aberto" localmente ainda existe de verdade no Jueri. Corrige o
# bug do pedido.deleted nunca tratado (ver JueriSyncService#sync_pedido_excluido
# e o commit que corrigiu isso) pra quem já ficou "preso" Aberto ANTES do
# fix — sem essa varredura, só pedidos excluídos DAQUI PRA FRENTE seriam
# pegos pelo webhook; os antigos ficariam errados pra sempre.
#
# Só LÊ do Jueri (GET /pedido/:id) — nunca escreve nada lá. A única escrita
# é local (Pedido#status_id vira Cancelado quando o Jueri confirma 404).
#
# Ritmo deliberadamente lento (mesma pausa que o resync em lote já usa,
# JueriSyncService::PAUSA_ENTRE_CHAMADAS) — o Jueri já demonstrou dar 429
# depois de ~300 chamadas em rajada; aqui não é rajada, é 1 chamada a cada
# 0.3s, então uma varredura de milhares de pedidos leva minutos, não
# segundos, de propósito. Resumível/idempotente: pode rodar de novo a
# qualquer momento, só reprocessa quem ainda está "Aberto".
class JueriReconciliarPedidosAbertosJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    return unless JueriApiService.configured?

    account = Account.find_by(id: account_id)
    return unless account

    api = JueriApiService.new
    sync_service = JueriSyncService.new(account: account)

    total = 0
    corrigidos = 0
    erros = 0

    account.pedidos.where(status_id: Pedido::STATUS_ABERTO).find_each.with_index do |pedido, index|
      sleep(JueriSyncService::PAUSA_ENTRE_CHAMADAS) if index.positive?
      total += 1

      begin
        api.find_pedido(pedido.jueri_pedido_id)
      rescue JueriApiService::ApiError => e
        if e.message.include?('404')
          sync_service.sync_pedido_excluido({ 'id' => pedido.jueri_pedido_id })
          corrigidos += 1
        else
          erros += 1
          Rails.logger.error("[JueriReconciliarPedidosAbertosJob] pedido=#{pedido.jueri_pedido_id} erro não-404: #{e.message}")
        end
      end
    end

    Rails.logger.info("[JueriReconciliarPedidosAbertosJob] account=#{account.id} total_checado=#{total} corrigidos=#{corrigidos} erros=#{erros}")
  end
end
