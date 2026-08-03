# Gatilhos de automação por etapa (botão "Automatize" no board). Restrito a dono/admin,
# igual PipelineStagesController — configurar automação não é operação do dia a dia.
class PipelineTriggersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner!
  before_action :set_stage, only: %i[create]
  before_action :set_trigger, only: %i[update destroy]

  def create
    trigger = @stage.pipeline_triggers.new(trigger_params)
    trigger.position = (@stage.pipeline_triggers.maximum(:position) || -1) + 1

    if trigger.save
      render json: trigger, status: :created
    else
      render json: { errors: trigger.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @trigger.update(trigger_params)
      render json: @trigger
    else
      render json: { errors: @trigger.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @trigger.destroy
    head :no_content
  end

  private

  def set_stage
    @stage = PipelineStage.joins(:pipeline).where(pipelines: { account_id: current_user.account_id }).find(params[:pipeline_stage_id])
  end

  def set_trigger
    @trigger = PipelineTrigger.joins(pipeline_stage: :pipeline).where(pipelines: { account_id: current_user.account_id }).find(params[:id])
  end

  def trigger_params
    params.require(:pipeline_trigger).permit(:action_type, :active, config: {})
  end
end
