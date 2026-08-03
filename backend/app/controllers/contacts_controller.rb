class ContactsController < ApplicationController
  before_action :set_contact, only: %i[ show update destroy merge add_note block unblock ]
  before_action :require_full_portfolio!, only: %i[ destroy merge ]

  # GET /contacts
  def index
    # Blacklist manual (Rev. Desconsiderados) some da listagem operacional pra
    # todo mundo — não é regra de permissão, é exclusão de qualidade de dado.
    # Quem precisar revisar um desconsiderado especificamente ainda consegue
    # abrir por ID direto (show não aplica esse filtro).
    @contacts = visible_contacts_scope.not_blacklisted

    page     = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 50).to_i.clamp(1, 200)
    @contacts = @contacts.includes(:reseller_phones).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)

    render json: @contacts.to_a.as_json(include: :reseller_phones)
  end

  # GET /contacts/ativas?data=2026-06-30 — Engine de Time Travel. Sem `data`,
  # devolve o snapshot de hoje (rápido, via colunas pré-calculadas). Respeita
  # o mesmo escopo de carteira do index (consultor só vê a própria).
  def ativas
    data = params[:data].present? ? Date.parse(params[:data]) : nil
    resultado = AtivasSnapshotService.new(
      contacts_scope: visible_contacts_scope,
      min_pecas_ativa: current_user.account.min_pecas_ativa,
      data: data
    ).call
    render json: { data_referencia: data || Date.current, total: resultado.size, revendedoras: resultado }
  rescue Date::Error, ArgumentError
    render json: { error: 'Data inválida. Use o formato YYYY-MM-DD.' }, status: :unprocessable_entity
  end

  # GET /contacts/1
  def show
    @contact = Contact.includes(conversations: :messages, notes: :user, reseller_phones: {}).find(@contact.id)
    render json: @contact.as_json(include: {
      conversations: {
        include: :messages
      },
      notes: {
        include: :user
      },
      reseller_phones: {}
    })
  end

  # POST /contacts
  def create
    @contact = Contact.new(contact_params)
    @contact.account_id = current_user.account_id
    @contact.user_id ||= current_user.id

    if @contact.save
      render json: @contact, status: :created, location: @contact
    else
      render json: @contact.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /contacts/1
  def update
    if @contact.update(contact_params)
      render json: @contact.as_json(include: :reseller_phones)
    else
      render json: @contact.errors, status: :unprocessable_content
    end
  end

  # DELETE /contacts/1
  def destroy
    @contact.destroy!
    head :no_content
  end

  # POST /contacts/1/merge
  def merge
    target_contact = current_user.account.contacts.find_by(id: params[:target_contact_id])
    if target_contact.nil? || target_contact.id == @contact.id
      return render json: { error: 'Invalid target contact' }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @contact.conversations.update_all(contact_id: target_contact.id)
      @contact.destroy!
    end

    render json: { message: 'Contacts merged successfully', contact: target_contact }
  end

  # POST /contacts/1/add_note
  def add_note
    note = @contact.notes.new(content: params[:content])
    note.account_id = @contact.account_id
    note.user_id = current_user.id

    if note.save
      render json: note.as_json(include: :user), status: :created
    else
      render json: note.errors, status: :unprocessable_entity
    end
  end

  def block
    @contact.update!(status: 'blocked')
    # Pausa a IA permanentemente para esse contato, em cada inbox onde ele tem conversa
    jid = @contact.channel_identifier
    if jid.present?
      @contact.conversations.where.not(inbox_id: nil).distinct.pluck(:inbox_id).each do |inbox_id|
        Rails.cache.write("ai_paused_#{inbox_id}_#{jid}", Time.current.to_i)
      end
    end
    render json: { message: 'Contato bloqueado com sucesso', status: 'blocked' }
  end

  def unblock
    @contact.update!(status: 'active')
    jid = @contact.channel_identifier
    if jid.present?
      @contact.conversations.where.not(inbox_id: nil).distinct.pluck(:inbox_id).each do |inbox_id|
        Rails.cache.delete("ai_paused_#{inbox_id}_#{jid}")
      end
    end
    render json: { message: 'Contato desbloqueado com sucesso', status: 'active' }
  end

  private
    # Escopo de leitura por perfil (briefing seção 22/30):
    # - full_portfolio (gerente/diretoria/admin/empresa) e finance (financeiro) veem
    #   a carteira inteira — financeiro precisa disso pra Inativas/cobrança cruzarem
    #   consultores.
    # - Consultor/atendente só veem a própria carteira (contact.user_id == self).
    def visible_contacts_scope
      base = current_user.account.contacts
      if full_portfolio? || finance? || current_user.permissions&.dig('view_all_contacts')
        base
      else
        base.where(user_id: current_user.id)
      end
    end

    # Use callbacks to share common setup or constraints between actions.
    # CRÍTICO: antes buscava em `current_user.account.contacts` sem filtrar por
    # dono — qualquer usuário autenticado conseguia abrir/editar QUALQUER contato
    # da conta só sabendo o ID, mesmo um consultor sem acesso àquela carteira no
    # index. Corrigido pra usar o mesmo escopo de `visible_contacts_scope`.
    def set_contact
      @contact = visible_contacts_scope.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'not_found', message: 'Contato não encontrado ou fora da sua carteira.' }, status: :not_found
    end

    # Only allow a list of trusted parameters through.
    def contact_params
      permitted = params.require(:contact).permit(
        :name, :email, :phone, :jid, :avatar_url, :status,
        :first_name, :last_name, :city, :country, :bio, :company_name,
        :temperature, :source, :intention,
        :cpf, :birth_date,
        :cep, :street, :neighborhood, :state, :address_number, :address_complement,
        custom_attributes: {}
      )
      # Transferência de responsável (briefing seção 22: "gerente transfere
      # revendedoras entre responsáveis") — só quem enxerga a carteira toda
      # pode reatribuir; consultor não pode se auto-transferir contato de outro.
      permitted[:user_id] = params[:contact][:user_id] if full_portfolio? && params[:contact]&.key?(:user_id)

      # Blacklist manual é override sensível — RBAC seção 7 do Tech Lead:
      # "Apenas Gerente, Financeiro e Admin podem aplicar overrides manuais".
      if (full_portfolio? || finance?) && params[:contact]
        permitted[:desconsiderado] = params[:contact][:desconsiderado] if params[:contact].key?(:desconsiderado)
        permitted[:desconsiderado_motivo] = params[:contact][:desconsiderado_motivo] if params[:contact].key?(:desconsiderado_motivo)
        if params[:contact][:desconsiderado].present? && ActiveModel::Type::Boolean.new.cast(params[:contact][:desconsiderado])
          permitted[:desconsiderado_at] = Time.current
        end
      end
      permitted
    end
end
