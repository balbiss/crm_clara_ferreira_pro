class ContactCustomFieldsController < ApplicationController
  before_action :authenticate_user!
  # Todo mundo lê (painel da conversa e "Editar campos" usam o nome do campo).
  # Só o dono cria/edita/apaga — mesma regra dos grupos de campos.
  before_action :require_owner!, only: %i[ create update destroy ]

  # Tipos de campo (Clara, 2026-10-16, igual Kommo). Campo antigo sem "type"
  # é texto curto. Seleção múltipla guarda o valor como LISTA em
  # custom_attributes (ex: ["Brinco", "Colar"]).
  TIPOS = %w[texto_curto texto_longo selecao_multipla].freeze

  # GET /contact_custom_fields
  def index
    render json: Array(current_user.account.contact_custom_fields).map { |f| normalizar(f) }
  end

  # POST /contact_custom_fields { label:, type:, options: [] }
  def create
    label = params[:label].to_s.strip
    return render json: { message: 'Dê um nome pro campo.' }, status: :unprocessable_entity if label.blank?

    account = current_user.account
    campos = Array(account.contact_custom_fields)
    if campos.any? { |f| f['label'].to_s.casecmp?(label) }
      return render json: { message: 'Já existe um campo com esse nome.' }, status: :unprocessable_entity
    end

    tipo, opcoes, erro = tipo_e_opcoes
    return render json: { message: erro }, status: :unprocessable_entity if erro

    base = "cf_#{I18n.transliterate(label).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '')}".first(40)
    key = base
    n = 2
    while campos.any? { |f| f['key'] == key } || ContactFieldGroup::ASSIGNABLE_FIELD_KEYS.include?(key)
      key = "#{base}_#{n}"
      n += 1
    end

    campo = { 'key' => key, 'label' => label, 'type' => tipo }
    campo['options'] = opcoes if tipo == 'selecao_multipla'
    account.update!(contact_custom_fields: campos + [campo])
    render json: campo, status: :created
  end

  # PATCH /contact_custom_fields/:id (id = key) { label:, type:, options: [] }
  # A key nunca muda — é ela que liga o campo aos valores já preenchidos.
  def update
    account = current_user.account
    campos = Array(account.contact_custom_fields)
    campo = campos.find { |f| f['key'] == params[:id] }
    return render json: { message: 'Campo não encontrado.' }, status: :not_found unless campo

    label = params[:label].to_s.strip.presence || campo['label']
    if campos.any? { |f| f['key'] != campo['key'] && f['label'].to_s.casecmp?(label) }
      return render json: { message: 'Já existe um campo com esse nome.' }, status: :unprocessable_entity
    end

    tipo, opcoes, erro = tipo_e_opcoes(padrao: campo['type'])
    return render json: { message: erro }, status: :unprocessable_entity if erro

    novo = { 'key' => campo['key'], 'label' => label, 'type' => tipo }
    novo['options'] = opcoes if tipo == 'selecao_multipla'
    account.update!(contact_custom_fields: campos.map { |f| f['key'] == campo['key'] ? novo : f })
    render json: novo
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

  private

  def normalizar(campo)
    campo = campo.to_h
    campo['type'] = 'texto_curto' unless TIPOS.include?(campo['type'])
    campo
  end

  # => [tipo, opcoes, mensagem_de_erro]
  def tipo_e_opcoes(padrao: nil)
    tipo = params[:type].to_s.presence || padrao.presence || 'texto_curto'
    return [nil, nil, 'Tipo de campo inválido.'] unless TIPOS.include?(tipo)

    opcoes = Array(params[:options]).map { |o| o.to_s.strip }.reject(&:blank?).uniq.first(50)
    if tipo == 'selecao_multipla' && opcoes.empty?
      return [nil, nil, 'Seleção múltipla precisa de pelo menos uma opção.']
    end

    [tipo, opcoes, nil]
  end
end
