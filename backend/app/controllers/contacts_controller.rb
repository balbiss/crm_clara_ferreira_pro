class ContactsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contact, only: %i[ show update destroy merge add_note block unblock ]
  before_action :require_full_portfolio!, only: %i[ destroy merge bulk_assign ]

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
    contacts_arr = @contacts.to_a

    # "Em vendas registradas" (RevendedorasAtivas.vue) precisa de um valor real —
    # antes somava custom_attributes.venda, um campo de texto livre que o
    # consultor preenche na mão e que ninguém nunca preencheu (dava sempre
    # R$ 0,00). valor_aberto é o valor de verdade, vindo dos pedidos
    # sincronizados do Jueri: soma em 1 query só (evita N+1 pra até 200 contatos).
    valores_abertos = Pedido.open_now.where(contact_id: contacts_arr.map(&:id))
                             .group(:contact_id).sum(:valor_total)

    # "Tempo de Revenda" e "1º Pedido" (revendedoras-ativas-criterios.md, seção
    # "Métricas Exibidas") — nº de MESES DISTINTOS com baixa (não é "desde o 1º
    # pedido", uma revendedora esporádica com poucos meses de baixa não conta
    # tempo parado no meio como revenda ativa) e a data do pedido mais antigo
    # da história. As duas em 1 query agregada cada, sem N+1.
    contact_ids = contacts_arr.map(&:id)
    tempo_revenda_meses = Pedido.where(contact_id: contact_ids).where.not(data_baixa: nil)
                                 .group(:contact_id).count("DISTINCT DATE_TRUNC('month', data_baixa)")
    primeiro_pedido_em = Pedido.where(contact_id: contact_ids).group(:contact_id).minimum(:data_criacao)

    json = contacts_arr.map do |c|
      c.as_json(include: :reseller_phones).merge(
        'valor_aberto' => valores_abertos[c.id].to_f,
        'tempo_revenda_meses' => tempo_revenda_meses[c.id] || 0,
        'primeiro_pedido_em' => primeiro_pedido_em[c.id]
      )
    end

    render json: json
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
    @contact = Contact.includes(conversations: :messages, notes: :user, reseller_phones: {}, tags: {}).find(@contact.id)
    render json: @contact.as_json(include: {
      conversations: {
        include: :messages
      },
      notes: {
        include: :user
      },
      reseller_phones: {},
      tags: {}
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

  # PATCH /contacts/bulk_assign — atribui (ou remove) o responsável de várias
  # revendedoras de uma vez, pra não precisar abrir modal por modal na tela
  # de triagem "Sem Responsável" (briefing seção 22: gerente reatribui carteira).
  def bulk_assign
    contact_ids = Array(params[:contact_ids])
    user_id = params[:user_id].presence

    if contact_ids.empty?
      return render json: { error: 'Selecione ao menos uma revendedora.' }, status: :unprocessable_entity
    end

    if user_id.present? && !current_user.account.users.exists?(id: user_id)
      return render json: { error: 'Consultor não encontrado nesta conta.' }, status: :unprocessable_entity
    end

    updated = current_user.account.contacts.where(id: contact_ids).update_all(user_id: user_id)
    render json: { updated: updated }
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
    # visible_contacts_scope agora mora em ApplicationController (reaproveitado
    # por ContactTagsController) — ver comentário lá.

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
