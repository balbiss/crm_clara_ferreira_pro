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
      # custom_attributes → carteira (gerente_jueri_nome, briefing seção 6) —
      # toda revendedora sincronizada do Jueri já tem isso, diferente do
      # responsável individual (user_id), que é atribuição manual e hoje está
      # vazio pra quase todo mundo. Tarefas.vue usa isso pra agrupar/filtrar
      # por time mesmo sem atribuição pessoa a pessoa.
      contact: { only: %i[id name phone status user_id custom_attributes] },
      user: { only: %i[id first_name last_name] }
    })
  end

  # PATCH /tarefas/1/complete
  # body opcional: { resultado: "...", proxima_tarefa: { tipo, titulo, descricao, prioridade, vencimento_em, user_id } }
  # Reforma do fluxo de tarefas (PDF Etapa 2, página 9): concluir passa a
  # registrar o que aconteceu e, se quiser, já cria o follow-up na hora —
  # antes era um clique só, sem nenhum registro pra gerência auditar depois.
  def complete
    @tarefa.concluir!(por: current_user, resultado: params[:resultado].presence)

    proxima = nil
    if params[:proxima_tarefa].present?
      pt = params[:proxima_tarefa]
      tipo = Tarefa::MANUAL_TIPOS.include?(pt[:tipo]) ? pt[:tipo] : 'manual_outro'
      begin
        proxima = current_user.account.tarefas.create!(
          contact_id: @tarefa.contact_id,
          user_id: pt[:user_id].presence || @tarefa.user_id,
          tipo: tipo,
          titulo: pt[:titulo].presence || Tarefa::MANUAL_TIPO_LABELS[tipo],
          descricao: pt[:descricao],
          prioridade: Tarefa::PRIORIDADES.include?(pt[:prioridade]) ? pt[:prioridade] : 'normal',
          vencimento_em: pt[:vencimento_em].presence || Time.current
        )
      rescue ActiveRecord::RecordNotUnique
        # já existe uma pendente do mesmo tipo manual pra essa revendedora —
        # a conclusão em si já foi salva, só não duplica o follow-up.
        proxima = nil
      end
    end

    render json: @tarefa.as_json.merge(proxima_tarefa: proxima)
  end

  # POST /tarefas — tarefa manual pra qualquer revendedora/consultor da conta
  # (briefing "Gerente: criar tarefas manuais para qualquer consultor").
  def create
    contact = current_user.account.contacts.find(tarefa_params[:contact_id])
    tarefa = current_user.account.tarefas.new(tarefa_params.except(:contact_id, :tipo))
    tarefa.contact = contact
    tarefa.tipo = Tarefa::MANUAL_TIPOS.include?(tarefa_params[:tipo]) ? tarefa_params[:tipo] : 'manual_outro'
    tarefa.vencimento_em ||= Time.current

    if tarefa.save
      render json: tarefa, status: :created
    else
      render json: { error: tarefa.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Revendedora não encontrada.' }, status: :not_found
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'ja_existe', message: 'Já existe uma tarefa desse tipo pendente para essa revendedora.' }, status: :unprocessable_entity
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
    params.require(:tarefa).permit(:contact_id, :user_id, :tipo, :titulo, :descricao, :prioridade, :vencimento_em)
  end

  # Consultor só vê tarefas da própria carteira (mesma regra de
  # ContactsController#visible_contacts_scope); gerente/diretoria/financeiro
  # veem tudo (auditoria/cobrança gerencial, briefing seção 24).
  def visible_tarefas_scope
    base = current_user.account.tarefas
    if full_portfolio? || finance? || current_user.permissions&.dig('view_all_contacts')
      base
    else
      lider_ids = current_user.accessible_jueri_lider_ids
      if lider_ids.any?
        base.left_joins(:contact).where(
          "tarefas.user_id = :uid OR contacts.custom_attributes ->> 'gerente_jueri_id' IN (:lider_ids)",
          uid: current_user.id, lider_ids: lider_ids
        )
      else
        base.where(user_id: current_user.id)
      end
    end
  end

  def set_tarefa
    @tarefa = visible_tarefas_scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Tarefa não encontrada ou fora da sua carteira.' }, status: :not_found
  end
end
