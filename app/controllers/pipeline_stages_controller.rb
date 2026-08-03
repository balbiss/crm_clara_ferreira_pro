class PipelineStagesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner!
  before_action :set_pipeline, only: %i[create]
  before_action :set_stage, only: %i[update destroy]

  def create
    stage = @pipeline.pipeline_stages.new(stage_params)
    stage.position = (@pipeline.pipeline_stages.maximum(:position) || -1) + 1

    if stage.save
      render json: stage, status: :created
    else
      render json: { errors: stage.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @stage.update(stage_params)
      render json: @stage
    else
      render json: { errors: @stage.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Não deixa apagar a última etapa, e move os cards da etapa apagada pra outra em vez
  # de deletar os contatos do pipeline junto.
  def destroy
    pipeline = @stage.pipeline
    if pipeline.pipeline_stages.count <= 1
      return render json: { error: 'O pipeline precisa de pelo menos uma etapa.' }, status: :unprocessable_entity
    end

    fallback = pipeline.pipeline_stages.where.not(id: @stage.id).order(:position).first
    @stage.pipeline_cards.update_all(pipeline_stage_id: fallback.id)
    @stage.destroy
    head :no_content
  end

  private

  def set_pipeline
    @pipeline = current_user.account.pipelines.find(params[:pipeline_id])
  end

  def set_stage
    @stage = PipelineStage.joins(:pipeline).where(pipelines: { account_id: current_user.account_id }).find(params[:id])
  end

  def stage_params
    params.require(:pipeline_stage).permit(:name, :color, :position)
  end
end
