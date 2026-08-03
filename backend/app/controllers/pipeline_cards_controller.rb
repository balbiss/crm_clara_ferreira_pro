# Mover/adicionar/remover contatos de um pipeline customizado. Liberado pra qualquer
# agente logado (diferente de PipelinesController/PipelineStagesController, que são só
# dono/admin) — arrastar um card no board é operação do dia a dia da consultora.
class PipelineCardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pipeline, only: %i[create]
  before_action :set_card, only: %i[update destroy]

  # GET /pipeline_cards            — todos os cards da conta, de todos os pipelines
  #                                   (tela "Todos os Leads")
  # GET /pipelines/:pipeline_id/pipeline_cards — só os cards daquele pipeline
  def index
    scope = if params[:pipeline_id]
      current_user.account.pipelines.find(params[:pipeline_id]).pipeline_cards
    else
      PipelineCard.joins(:pipeline).where(pipelines: { account_id: current_user.account_id })
    end
    cards = scope.includes(:contact, :pipeline, :pipeline_stage).order(:position, :id)
    render json: cards.map { |c| serialize(c) }
  end

  def create
    stage = @pipeline.pipeline_stages.find(params[:pipeline_stage_id].presence || @pipeline.pipeline_stages.first.id)
    card = @pipeline.pipeline_cards.new(pipeline_stage: stage, contact_id: params[:contact_id])
    card.position = (@pipeline.pipeline_cards.where(pipeline_stage: stage).maximum(:position) || -1) + 1

    if card.save
      PipelineTriggerRunnerService.new(card).call
      render json: serialize(card.reload), status: :created
    else
      render json: { errors: card.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    stage_changed = card_params[:pipeline_stage_id].present? && card_params[:pipeline_stage_id].to_i != @card.pipeline_stage_id

    if @card.update(card_params)
      PipelineTriggerRunnerService.new(@card).call if stage_changed
      render json: serialize(@card.reload)
    else
      render json: { errors: @card.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @card.destroy
    head :no_content
  end

  private

  def set_pipeline
    @pipeline = current_user.account.pipelines.find(params[:pipeline_id])
  end

  def set_card
    @card = PipelineCard.joins(:pipeline).where(pipelines: { account_id: current_user.account_id }).find(params[:id])
  end

  def card_params
    params.require(:pipeline_card).permit(:pipeline_stage_id, :position)
  end

  def serialize(card)
    c = card.contact
    {
      id: card.id,
      pipeline_id: card.pipeline_id,
      pipeline_name: card.pipeline.name,
      pipeline_stage_id: card.pipeline_stage_id,
      pipeline_stage_name: card.pipeline_stage.name,
      position: card.position,
      contact: {
        id: c.id,
        name: c.name.presence || "#{c.first_name} #{c.last_name}".strip,
        phone: c.phone,
        temperature: c.temperature,
        user_id: c.user_id,
        venda: c.custom_attributes&.dig('venda')
      }
    }
  end
end
