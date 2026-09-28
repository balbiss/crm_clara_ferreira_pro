class MessageTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[ update destroy ]
  # Corretores podem listar (pra usar o "/" na conversa). Só o dono
  # cria/edita/apaga modelo -- mesma regra de TagsController.
  before_action :require_owner!, only: %i[ create update destroy ]

  # GET /message_templates
  def index
    render json: current_user.account.message_templates.ordered
  end

  # POST /message_templates
  def create
    @template = current_user.account.message_templates.build(template_params)

    if @template.save
      render json: @template, status: :created
    else
      render json: @template.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /message_templates/1
  def update
    if @template.update(template_params)
      render json: @template
    else
      render json: @template.errors, status: :unprocessable_entity
    end
  end

  # DELETE /message_templates/1
  def destroy
    @template.destroy!
  end

  private
    def set_template
      @template = current_user.account.message_templates.find(params[:id])
    end

    def template_params
      params.require(:message_template).permit(:nome, :categoria, :mensagem)
    end
end
