# Agenda/calendário: cada usuário cria/edita/apaga os próprios compromissos;
# gerente/diretoria (full_portfolio?) enxergam e gerenciam a agenda de todo
# mundo, com filtro por responsável (?user_id=). Mesmo modelo de permissão já
# usado em TarefasController, só que sem a distinção extra pra financeiro —
# agenda geral não é dado de cobrança.
class AgendamentosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_agendamento, only: %i[update destroy]

  # GET /agendamentos?de=2026-08-01&ate=2026-08-31&user_id=5
  def index
    de = parse_date(params[:de]) || Date.current.beginning_of_month
    ate = parse_date(params[:ate]) || Date.current.end_of_month

    agendamentos = visible_agendamentos_scope.no_periodo(de.beginning_of_day, ate.end_of_day)
    agendamentos = agendamentos.where(user_id: params[:user_id]) if params[:user_id].present? && full_portfolio?

    render json: agendamentos.order(:inicio_em).includes(:user, :contact).as_json(include: JSON_INCLUDES)
  end

  # POST /agendamentos
  def create
    agendamento = current_user.account.agendamentos.new(agendamento_params.except(:user_id))
    # Só gerente/diretoria pode criar um compromisso em nome de outra pessoa
    # (ex: agendar reunião pra um consultor) — todo mundo mais vira dono do
    # próprio evento, sem exceção.
    agendamento.user_id = full_portfolio? ? (agendamento_params[:user_id].presence || current_user.id) : current_user.id

    if agendamento.save
      render json: agendamento.as_json(include: JSON_INCLUDES), status: :created
    else
      render json: { error: agendamento.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # PATCH /agendamentos/1
  def update
    prms = agendamento_params
    prms = prms.except(:user_id) unless full_portfolio?

    if @agendamento.update(prms)
      render json: @agendamento.as_json(include: JSON_INCLUDES)
    else
      render json: { error: @agendamento.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # DELETE /agendamentos/1
  def destroy
    @agendamento.destroy!
    head :no_content
  end

  private

  JSON_INCLUDES = {
    user: { only: %i[id first_name last_name] },
    contact: { only: %i[id name phone] }
  }.freeze

  def agendamento_params
    params.require(:agendamento).permit(:titulo, :descricao, :inicio_em, :fim_em, :user_id, :contact_id, :valor, :tipo)
  end

  # Consultor/financeiro só veem/gerenciam a própria agenda; gerente/diretoria
  # veem e gerenciam a de todo mundo (inclusive pra reatribuir/apagar
  # compromisso errado de outra pessoa).
  def visible_agendamentos_scope
    base = current_user.account.agendamentos
    full_portfolio? ? base : base.where(user_id: current_user.id)
  end

  def set_agendamento
    @agendamento = visible_agendamentos_scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Agendamento não encontrado ou não é seu.' }, status: :not_found
  end

  def parse_date(str)
    return nil if str.blank?
    Date.parse(str)
  rescue ArgumentError
    nil
  end
end
