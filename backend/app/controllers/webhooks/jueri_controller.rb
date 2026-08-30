# Recebe eventos do Jueri (pedido.created/updated/deleted/canceled, venda.*,
# financeiro.contas_receber.*, financeiro.contas_pagar.* — ver openapi.yaml do Jueri).
# Autenticação é o token na própria URL (gerado por conta em Account#jueri_webhook_token,
# igual ao :token usado ao registrar o webhook no Jueri via JueriApiService#create_webhook).
#
# Dois caminhos em paralelo, propositalmente:
#
# 1. Fast path (SEM debounce, todo evento pedido.*): o payload do próprio
#    evento já traz o pedido inteiro (mesmos campos da listagem em lote, só
#    que com fk_status_pedido_id numérico em vez de status string — ver
#    JueriSyncService#status_id_de), então dá pra aplicar SÓ essa revendedora
#    na hora (JueriWebhookPedidoJob), sem esperar o histórico completo.
#    Cobre pedido.created/updated/deleted/canceled — os eventos que mudam
#    peças abertas e por isso a régua (ativação/reativação/sem maleta).
#
# 2. Resync completo debounced (30s, como já era): continua rodando pra
#    TODOS os eventos (inclusive os de fast path, como reconciliação) —
#    é quem cobre revendedor.*/financeiro.*/venda.* (cadastro, sem campo
#    equivalente no payload do webhook pra aplicar via fast path) e qualquer
#    divergência que o fast path deixe passar.
module Webhooks
  class JueriController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    DEBOUNCE_SECONDS = 30
    EVENTOS_PEDIDO = %w[pedido.created pedido.updated pedido.deleted pedido.canceled].freeze

    def create
      account = Account.find_by(jueri_webhook_token: params[:token])
      return head :not_found unless account

      evento = params[:evento] || params[:event] || params.dig(:data, :evento)
      payload = params.except(:controller, :action, :token, :jueri).to_unsafe_h
      # Payload completo no log (não em coluna própria — mesmo padrão dos
      # outros webhooks, ver Webhooks::BaileysController) pra investigar
      # mudança de formato da API sem precisar confiar nos campos aqui.
      Rails.logger.info("[Webhooks::Jueri] account=#{account.id} evento=#{evento.inspect} payload=#{payload.to_json}")

      # pedido.deleted não precisa de fk_revendedor_id no payload — o job
      # acha a revendedora pelo próprio Pedido já salvo localmente (ver
      # JueriSyncService#sync_pedido_excluido). Os outros 3 eventos de
      # pedido continuam exigindo fk_revendedor_id (payload completo).
      if evento == 'pedido.deleted'
        JueriWebhookPedidoJob.perform_later(account.id, payload, evento)
      elsif EVENTOS_PEDIDO.include?(evento) && payload['fk_revendedor_id'].present?
        JueriWebhookPedidoJob.perform_later(account.id, payload, evento)
      end

      debounce_key = "jueri_webhook_sync_#{account.id}"
      unless Rails.cache.read(debounce_key)
        Rails.cache.write(debounce_key, true, expires_in: DEBOUNCE_SECONDS)
        JueriSyncJob.perform_later(account.id)
      end

      head :ok
    end
  end
end
