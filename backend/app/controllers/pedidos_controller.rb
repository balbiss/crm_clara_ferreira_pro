# "Pedidos Pendentes" — mesma lista que o widget do painel do Jueri mostra
# (pedidos com status Aberto = fk_status_pedido_id 1, ainda não baixados/
# cancelados). Não chama a API do Jueri: já sincronizamos todo pedido em
# `Pedido` via JueriSyncService, então essa tela é só uma leitura filtrada
# do que já está local — nenhum custo de API novo.
class PedidosController < ApplicationController
  before_action :authenticate_user!

  # GET /pedidos/pendentes?page=1&per_page=20
  def pendentes
    page = [(params[:page] || 1).to_i, 1].max
    per_page = (params[:per_page] || 20).to_i.clamp(1, 100)

    scope = Pedido
      .where(account_id: current_user.account_id, status_id: Pedido::STATUS_ABERTO)
      .where(contact_id: visible_contacts_scope.select(:id))
      .includes(:contact)
      .order(data_criacao: :desc, id: :desc)
    scope = scope.where(contact_id: params[:contact_id]) if params[:contact_id].present?

    total = scope.count
    pedidos = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      total: total,
      page: page,
      per_page: per_page,
      total_pages: total.zero? ? 1 : (total.to_f / per_page).ceil,
      pedidos: pedidos.map { |p| serialize(p) }
    }
  end

  private

  def serialize(pedido)
    contact = pedido.contact
    {
      id: pedido.id,
      jueri_pedido_id: pedido.jueri_pedido_id,
      contact_id: contact&.id,
      contact_name: contact&.name.presence || contact&.phone,
      quantidade: pedido.quantidade,
      quantidade_antes_baixa: pedido.quantidade_antes_baixa,
      valor_total: pedido.valor_total,
      status_id: pedido.status_id,
      data_criacao: pedido.data_criacao,
      data_baixa: pedido.data_baixa,
      data_cancelamento: pedido.data_cancelamento,
      updated_at: pedido.updated_at
    }
  end
end
