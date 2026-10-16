class MessageTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[ update destroy ]

  # Dois tipos (pedido da Clara, 2026-10-16):
  # - GERAL (user_id nil): todo mundo usa; só diretoria cria/edita/apaga
  #   (mesma regra de antes, quando só existia esse tipo).
  # - INDIVIDUAL (user_id = dono): cada usuário cria/edita/apaga os seus;
  #   ninguém mais vê.

  # GET /message_templates — gerais + os meus.
  def index
    templates = current_user.account.message_templates.visible_to(current_user).ordered
    render json: templates.map { |t| serialize(t) }
  end

  # POST /message_templates
  def create
    @template = current_user.account.message_templates.build(template_params)
    @template.user = escopo_param == 'geral' ? nil : current_user
    return forbidden_geral if @template.geral? && !owner?

    if @template.save
      render json: serialize(@template), status: :created
    else
      render json: @template.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /message_templates/1
  def update
    return forbidden_geral unless pode_editar?(@template)

    # Diretoria pode mudar o tipo; os outros só mexem nos individuais deles.
    if escopo_param.present? && owner?
      @template.user = escopo_param == 'geral' ? nil : (@template.user || current_user)
    end

    @template.attachment.purge if params.dig(:message_template, :remove_attachment) == 'true' && @template.attachment.attached?

    if @template.update(template_params)
      render json: serialize(@template)
    else
      render json: @template.errors, status: :unprocessable_entity
    end
  end

  # DELETE /message_templates/1
  def destroy
    return forbidden_geral unless pode_editar?(@template)

    @template.destroy!
  end

  private
    def set_template
      @template = current_user.account.message_templates.visible_to(current_user).find(params[:id])
    end

    def template_params
      params.require(:message_template).permit(:nome, :categoria, :mensagem, :attachment)
    end

    def escopo_param
      params.dig(:message_template, :escopo).to_s
    end

    def pode_editar?(template)
      template.geral? ? owner? : template.user_id == current_user.id
    end

    def forbidden_geral
      render json: { error: 'forbidden', message: 'Só a diretoria cria e edita modelos gerais. Salve como "Meu modelo".' }, status: :forbidden
    end

    def serialize(template)
      template.as_json.merge(
        'attachment_url' => template.attachment_url,
        'attachment_type' => template.attachment_type,
        'escopo' => template.geral? ? 'geral' : 'individual',
        'pode_editar' => pode_editar?(template)
      )
    end
end
