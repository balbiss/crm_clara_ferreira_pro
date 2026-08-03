# Pipelines customizáveis (Varejo, Onboarding, Atacado, Prospecção etc). Criar/editar/
# apagar é restrito a dono/admin — ver a listagem é liberado pra qualquer agente logado,
# já que o board em si (mover cards) não exige ser dono.
class PipelinesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pipeline, only: %i[update destroy]
  before_action :require_owner!, only: %i[create update destroy]

  def index
    pipelines = current_user.account.pipelines.includes(pipeline_stages: :pipeline_triggers).order(:position, :id)
    render json: pipelines.as_json(
      only: %i[id name slug position system],
      include: {
        pipeline_stages: {
          only: %i[id name color position],
          include: { pipeline_triggers: { only: %i[id action_type config position active] } }
        }
      }
    )
  end

  def create
    pipeline = current_user.account.pipelines.new(pipeline_params)
    pipeline.position = (current_user.account.pipelines.maximum(:position) || 0) + 1

    if pipeline.save
      pipeline.pipeline_stages.create!(name: 'Novo Lead', position: 0)
      render json: pipeline.as_json(include: :pipeline_stages), status: :created
    else
      render json: { errors: pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @pipeline.update(pipeline_params)
      render json: @pipeline
    else
      render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @pipeline.system?
      render json: { error: 'Este pipeline não pode ser removido.' }, status: :forbidden
    else
      @pipeline.destroy
      head :no_content
    end
  end

  private

  def set_pipeline
    @pipeline = current_user.account.pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :position)
  end
end
