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
# INCIDENTE REAL (2026-08-30): a primeira versão rodava tudo de uma vez com
# 0.3s de pausa (mesmo ritmo do resync em lote) — na prática isso ainda foi
# rápido demais: o rate limit do Jueri é POR CONTA (não por endpoint/job),
# e 776 pedidos nesse ritmo tomaram 429 em cascata E travaram a fila do
# Solid Queue tempo suficiente pra atrasar o JueriSyncJob recorrente em
# ~30min, que por sua vez também começou a tomar 429 (efeito dominó).
# Reescrito em LOTES pequenos (BATCH_SIZE) com pausa maior entre chamadas
# E um intervalo entre lotes (se reagenda sozinho) — nunca monopoliza a
# fila por muito tempo seguido, e dá bastante folga pro rate limit
# "esfriar" entre lotes.
class JueriReconciliarPedidosAbertosJob < ApplicationJob
  queue_as :default

  PAUSA_ENTRE_CHAMADAS = 2.0
  BATCH_SIZE = 30
  INTERVALO_ENTRE_LOTES = 90.seconds

  def perform(account_id, cursor_id = 0)
    return unless JueriApiService.configured?

    account = Account.find_by(id: account_id)
    return unless account

    api = JueriApiService.new
    sync_service = JueriSyncService.new(account: account)

    pedidos = account.pedidos.where(status_id: Pedido::STATUS_ABERTO).where('id > ?', cursor_id).order(:id).limit(BATCH_SIZE)

    if pedidos.empty?
      Rails.logger.info("[JueriReconciliarPedidosAbertosJob] account=#{account.id} varredura completa (cursor final=#{cursor_id})")
      return
    end

    corrigidos = 0
    last_id = cursor_id

    pedidos.each_with_index do |pedido, index|
      sleep(PAUSA_ENTRE_CHAMADAS) if index.positive?
      last_id = pedido.id

      begin
        api.find_pedido(pedido.jueri_pedido_id)
      rescue JueriApiService::ApiError => e
        if e.message.include?('404')
          sync_service.sync_pedido_excluido({ 'id' => pedido.jueri_pedido_id })
          corrigidos += 1
        elsif e.message.include?('429')
          # Rate limit ainda ativo — para esse lote na hora (não insiste) e
          # tenta de novo mais adiante, com folga extra.
          Rails.logger.warn("[JueriReconciliarPedidosAbertosJob] 429 no meio do lote, pausando — retomando depois de #{cursor_id}")
          JueriReconciliarPedidosAbertosJob.set(wait: INTERVALO_ENTRE_LOTES * 2).perform_later(account.id, cursor_id)
          return
        else
          Rails.logger.error("[JueriReconciliarPedidosAbertosJob] pedido=#{pedido.jueri_pedido_id} erro: #{e.message}")
        end
      end
    end

    Rails.logger.info("[JueriReconciliarPedidosAbertosJob] account=#{account.id} lote até id=#{last_id} corrigidos=#{corrigidos}")

    JueriReconciliarPedidosAbertosJob.set(wait: INTERVALO_ENTRE_LOTES).perform_later(account.id, last_id)
  end
end
