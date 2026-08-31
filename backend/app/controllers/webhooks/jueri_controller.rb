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

      registrar_atividade(account, evento, payload)

      # pedido.deleted não precisa de fk_revendedor_id no payload — o job
      # acha a revendedora pelo próprio Pedido já salvo localmente (ver
      # JueriSyncService#sync_pedido_excluido). Os outros 3 eventos de
      # pedido continuam exigindo fk_revendedor_id (payload completo).
      if evento == 'pedido.deleted'
        JueriWebhookPedidoJob.perform_later(account.id, payload, evento)
      elsif EVENTOS_PEDIDO.include?(evento) && payload['fk_revendedor_id'].present?
        JueriWebhookPedidoJob.perform_later(account.id, payload, evento)
      elsif evento == 'revendedor.created'
        notificar_novo_cadastro(account, payload)
      end

      debounce_key = "jueri_webhook_sync_#{account.id}"
      unless Rails.cache.read(debounce_key)
        Rails.cache.write(debounce_key, true, expires_in: DEBOUNCE_SECONDS)
        JueriSyncJob.perform_later(account.id)
      end

      head :ok
    end

    private

    # Avisa dono/gerente (pedido do cliente: só esses dois perfis, não
    # consultor/financeiro) quando entra revendedora nova no Jueri. O nome do
    # campo "quem cadastrou" no payload ainda não foi confirmado contra um
    # evento real (não achamos nos logs — provavelmente rotacionados por
    # deploy) — tenta as chaves mais prováveis (mesmo padrão do campo
    # "vendedor" já visto no payload de pedido) com fallback silencioso.
    # Payload completo já fica no log logo acima, então dá pra ajustar o
    # nome certo da chave assim que um evento real passar por aqui.
    def notificar_novo_cadastro(account, payload)
      mensagem = descricao_para('revendedor.created', payload)

      Notification.create!(
        account: account,
        audience: 'owner_level',
        title: 'Novo cadastro no Jueri',
        message: mensagem,
        link: '/carteira'
      )

      account.users.where(role: User::OWNER_LEVEL_ROLES).find_each do |user|
        WebPushService.notify(user, title: 'Novo cadastro no Jueri', body: mensagem, url: '/carteira', tag: 'jueri-revendedor-created')
      end
    rescue StandardError => e
      Rails.logger.error("[Webhooks::Jueri] falha ao notificar revendedor.created: #{e.message}")
    end

    # Feed de atividade genérico (tela "Atividades", só gerência) — TODO
    # evento que chega no webhook vira uma linha aqui, sem notificação/push
    # (diferente do cadastro novo acima): pedido aberto muda de valor várias
    # vezes por dia, virar aviso a cada mudança seria barulho demais. É só
    # pra consulta, inspirado no painel "Atividades do Dia" da própria Jueri.
    def registrar_atividade(account, evento, payload)
      return if evento.blank?

      id_jueri = payload['fk_revendedor_id'] || payload.dig('revendedor', 'id') || payload.dig('comprador', 'id')
      contact = id_jueri.present? ? account.contacts.find_by(id_jueri: id_jueri.to_s) : nil

      JueriActivity.create!(
        account: account,
        contact: contact,
        evento: evento,
        descricao: descricao_para(evento, payload),
        ocorrido_em: Time.current,
        payload: payload
      )
    rescue StandardError => e
      Rails.logger.error("[Webhooks::Jueri] falha ao registrar atividade: #{e.message}")
    end

    def descricao_para(evento, payload)
      case evento
      when 'revendedor.created', 'revendedor.updated'
        revendedor = payload['revendedor'].is_a?(Hash) ? payload['revendedor'] : payload
        nome = revendedor['nome'].presence || 'Revendedora sem nome'
        if evento == 'revendedor.created'
          autor = payload['usuario'].presence || payload['criado_por'].presence ||
            payload.dig('revendedor', 'usuario').presence || 'não identificado'
          "#{nome} — cadastro novo (por #{autor})"
        else
          "#{nome} — cadastro atualizado"
        end
      when /\Apedido\./
        codigo = payload['codigo_pedido'] || payload['id']
        valor = payload['valor_total'].presence
        valor_fmt = valor ? "R$ #{format('%.2f', valor.to_f).tr('.', ',')}" : nil
        acao = {
          'pedido.created'  => 'aberto',
          'pedido.updated'  => 'atualizado',
          'pedido.deleted'  => 'excluído/unificado',
          'pedido.canceled' => 'cancelado'
        }.fetch(evento, evento)
        ["Pedido ##{codigo}", "— #{acao}", valor_fmt].compact.join(' ')
      else
        "Evento #{evento}"
      end
    end
  end
end
