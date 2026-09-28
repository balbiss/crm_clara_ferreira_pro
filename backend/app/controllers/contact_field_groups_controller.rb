class ContactFieldGroupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group, only: %i[ update destroy ]
  # Todo mundo lê (o painel da conversa usa isso pra montar as sanfonas).
  # Só o dono cria/edita/apaga grupo -- mesma regra de TagsController.
  before_action :require_owner!, only: %i[ create update destroy ]

  # GET /contact_field_groups
  def index
    ContactFieldGroup.seed_default_for(current_user.account)
    render json: current_user.account.contact_field_groups.ordered
  end

  # POST /contact_field_groups
  def create
    max_position = current_user.account.contact_field_groups.maximum(:position) || -1
    @group = current_user.account.contact_field_groups.build(group_params.merge(position: max_position + 1))

    if @group.save
      render json: @group, status: :created
    else
      render json: @group.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /contact_field_groups/1
  def update
    if @group.update(group_params)
      render json: @group
    else
      render json: @group.errors, status: :unprocessable_entity
    end
  end

  # DELETE /contact_field_groups/1
  def destroy
    @group.destroy!
  end

  private
    def set_group
      @group = current_user.account.contact_field_groups.find(params[:id])
    end

    # field_keys nunca pode conter um campo do Jueri -- filtra pra dentro da
    # whitelist mesmo que alguém tente mandar outra coisa na requisição
    # (regra dura pedida pela dona, 2026-09-28: "não pode editar dados do jueri").
    def group_params
      permitted = params.require(:contact_field_group).permit(:name, field_keys: [])
      if permitted[:field_keys]
        permitted[:field_keys] = permitted[:field_keys] & ContactFieldGroup::ASSIGNABLE_FIELD_KEYS
      end
      permitted
    end
end
