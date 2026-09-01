# Gatilhos de automação por status da régua consignada (botão "Automatize" no
# Kanban.vue). Restrito a dono/admin, igual PipelineTriggersController.
class ReguaTriggersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner!
  before_action :set_trigger, only: %i[update destroy]

  def index
    triggers = current_user.account.regua_triggers.order(:status, :position)
    render json: triggers
  end

  def create
    trigger = current_user.account.regua_triggers.new(trigger_params)
    trigger.position = (current_user.account.regua_triggers.where(status: trigger.status).maximum(:position) || -1) + 1

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

  def set_trigger
    @trigger = current_user.account.regua_triggers.find(params[:id])
  end

  def trigger_params
    params.require(:regua_trigger).permit(:status, :action_type, :active, :delay_minutes, config: {})
  end
end
