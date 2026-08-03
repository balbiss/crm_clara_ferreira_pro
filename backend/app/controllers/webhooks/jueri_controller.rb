# Recebe eventos do Jueri (pedido.created/updated/deleted/canceled, venda.*,
# financeiro.contas_receber.*, financeiro.contas_pagar.* — ver openapi.yaml do Jueri).
# Autenticação é o token na própria URL (gerado por conta em Account#jueri_webhook_token,
# igual ao :token usado ao registrar o webhook no Jueri via JueriApiService#create_webhook).
#
# Em vez de tentar interpretar o payload de cada tipo de evento (o formato exato não é
# documentado publicamente pelo Jueri), qualquer evento relevante dispara uma
# sincronização pontual da conta — mais simples e robusto do que replicar a lógica de
# negócio do ERP aqui. Uma rajada de eventos vira só uma sincronização (debounce de
# 30s via cache) pra não estourar o rate limit da API do Jueri.
module Webhooks
  class JueriController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    DEBOUNCE_SECONDS = 30

    def create
      account = Account.find_by(jueri_webhook_token: params[:token])
      return head :not_found unless account

      evento = params[:evento] || params[:event] || params.dig(:data, :evento)
      Rails.logger.info("[Webhooks::Jueri] account=#{account.id} evento=#{evento.inspect}")

      debounce_key = "jueri_webhook_sync_#{account.id}"
      unless Rails.cache.read(debounce_key)
        Rails.cache.write(debounce_key, true, expires_in: DEBOUNCE_SECONDS)
        JueriSyncJob.perform_later(account.id)
      end

      head :ok
    end
  end
end
