class ContactCustomFieldsController < ApplicationController
  before_action :authenticate_user!
  # Todo mundo lê (painel da conversa e "Editar campos" usam o nome do campo).
  # Só o dono cria/apaga — mesma regra dos grupos de campos.
  before_action :require_owner!, only: %i[ create destroy ]

  # GET /contact_custom_fields
  def index
    render json: current_user.account.contact_custom_fields
  end

  # POST /contact_custom_fields { label: "Mais vende" }
  def create
    label = params[:label].to_s.strip
    return render json: { message: 'Dê um nome pro campo.' }, status: :unprocessable_entity if label.blank?

    account = current_user.account
    campos = Array(account.contact_custom_fields)
    if campos.any? { |f| f['label'].to_s.casecmp?(label) }
      return render json: { message: 'Já existe um campo com esse nome.' }, status: :unprocessable_entity
    end

    base = "cf_#{I18n.transliterate(label).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '')}".first(40)
    key = base
    n = 2
    while campos.any? { |f| f['key'] == key } || ContactFieldGroup::ASSIGNABLE_FIELD_KEYS.include?(key)
      key = "#{base}_#{n}"
      n += 1
    end

    campo = { 'key' => key, 'label' => label }
    account.update!(contact_custom_fields: campos + [campo])
    render json: campo, status: :created
  end

  # DELETE /contact_custom_fields/:id (id = key do campo). Tira o campo dos
  # grupos também; o valor já preenchido nas revendedoras fica guardado em
  # custom_attributes (não apaga dado de ninguém).
  def destroy
    account = current_user.account
    account.update!(contact_custom_fields: Array(account.contact_custom_fields).reject { |f| f['key'] == params[:id] })
    account.contact_field_groups.each do |g|
      next unless Array(g.field_keys).include?(params[:id])
      g.update!(field_keys: g.field_keys - [params[:id]])
    end
    head :no_content
  end
end
