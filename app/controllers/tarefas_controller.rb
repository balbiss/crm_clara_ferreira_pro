class TarefasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tarefa, only: %i[complete]

  # GET /tarefas?status=pendente&tipo=atrasada&vencidas=true&user_id=5
  def index
    tarefas = visible_tarefas_scope.includes(:contact, :user)

    tarefas = tarefas.where(status: params[:status]) if params[:status].present?
    tarefas = tarefas.where(tipo: params[:tipo]) if params[:tipo].present?
    tarefas = tarefas.where(user_id: params[:user_id]) if params[:user_id].present?
    tarefas = tarefas.vencidas if params[:vencidas] == 'true'
    tarefas = tarefas.do_dia if params[:do_dia] == 'true'

    tarefas = tarefas.order(
      Arel.sql("CASE prioridade WHEN 'urgente' THEN 0 WHEN 'alta' THEN 1 ELSE 2 END"),
      vencimento_em: :asc
    )

    render json: tarefas.as_json(include: {
      contact: { only: %i[id name phone status user_id] },
      user: { only: %i[id first_name last_name] }
    })
  end

  # PATCH /tarefas/1/complete
  def complete
    @tarefa.concluir!(por: current_user)
    render json: @tarefa
  end

  private

  # Consultor só vê tarefas da própria carteira (mesma regra de
  # ContactsController#visible_contacts_scope); gerente/diretoria/financeiro
  # veem tudo (auditoria/cobrança gerencial, briefing seção 24).
  def visible_tarefas_scope
    base = current_user.account.tarefas
    if full_portfolio? || finance? || current_user.permissions&.dig('view_all_contacts')
      base
    else
      base.where(user_id: current_user.id)
    end
  end

  def set_tarefa
    @tarefa = visible_tarefas_scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Tarefa não encontrada ou fora da sua carteira.' }, status: :not_found
  end
end
