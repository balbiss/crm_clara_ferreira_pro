class TarefasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tarefa, only: %i[complete update destroy]
  # Tarefa manual (criar/reatribuir/cancelar) é ação de gestão de carteira —
  # gerente/diretoria, igual à transferência de responsável em ContactsController.
  before_action :require_full_portfolio!, only: %i[create update destroy]

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

  # POST /tarefas — tarefa manual pra qualquer revendedora/consultor da conta
  # (briefing "Gerente: criar tarefas manuais para qualquer consultor").
  def create
    contact = current_user.account.contacts.find(tarefa_params[:contact_id])
    tarefa = current_user.account.tarefas.new(tarefa_params.except(:contact_id))
    tarefa.contact = contact
    tarefa.tipo = 'manual'
    tarefa.vencimento_em ||= Time.current

    if tarefa.save
      render json: tarefa, status: :created
    else
      render json: { error: tarefa.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Revendedora não encontrada.' }, status: :not_found
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'ja_existe', message: 'Já existe uma tarefa manual pendente para essa revendedora.' }, status: :unprocessable_entity
  end

  # PATCH /tarefas/1 — reatribuir responsável (tarefa atrasada/sem dono) ou
  # editar uma tarefa manual (briefing "Gerente: reatribuir tarefas atrasadas").
  def update
    if @tarefa.update(tarefa_params.except(:contact_id))
      render json: @tarefa
    else
      render json: { error: @tarefa.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # DELETE /tarefas/1 — cancelar tarefa/agendamento incorreto (briefing
  # "Gerente: pode cancelar/deletar agendamentos ou tarefas incorretas").
  def destroy
    @tarefa.destroy!
    head :no_content
  end

  private

  def tarefa_params
    params.require(:tarefa).permit(:contact_id, :user_id, :titulo, :descricao, :prioridade, :vencimento_em)
  end

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
