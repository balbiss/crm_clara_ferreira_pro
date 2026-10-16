# TEMPORÁRIO (2026-10-15) — relatórios FIXOS de diagnóstico (somente leitura),
# sem SQL livre. Só responde com a chave em ENV['DIAG_TOKEN'] (sem a env,
# a rota é 404). REMOVER este controller, a rota e a env depois do uso.
class DiagController < ApplicationController
  before_action :check_token

  # GET /diag/contato?q=nome ou telefone — cadastros que batem e todas as
  # conversas de cada um (caixa, atendente, nº de mensagens, 1ª/última).
  def contato
    contatos = Contact.search_by_name_or_phone(params[:q].to_s).limit(15)
    render json: contatos.map { |ct| contato_json(ct) }
  end

  # GET /diag/recentes — conversas criadas nos últimos N dias (padrão 3) cujo
  # telefone (8 últimos dígitos) também existe em OUTRO cadastro.
  def recentes
    dias = (params[:dias].presence || 3).to_i.clamp(1, 15)
    convs = Conversation.where('conversations.created_at > ?', dias.days.ago).includes(:contact, :inbox)
    suspeitas = convs.select do |c|
      fone = c.contact&.phone.to_s.gsub(/\D/, '')[-8..]
      fone.present? && Contact.where(account_id: c.account_id).where.not(id: c.contact_id)
                              .where("right(regexp_replace(coalesce(phone,''), '\\D', '', 'g'), 8) = ?", fone).exists?
    end
    render json: suspeitas.first(60).map { |c| conversa_json(c).merge(contato: c.contact&.slice(:id, :name, :phone, :jid, :user_id, :created_at)) }
  end

  # GET /diag/caixas — configuração de cada caixa.
  def caixas
    render json: Inbox.order(:id).map { |i|
      i.slice(:id, :name, :provider, :phone_number, :restrict_by_portfolio, :sign_messages, :ai_enabled).merge(
        conversas: i.conversations.count
      )
    }
  end

  private

  def check_token
    expected = ENV['DIAG_TOKEN'].to_s
    given = request.headers['X-Diag-Token'].to_s
    head :not_found if expected.length < 32 || !ActiveSupport::SecurityUtils.secure_compare(given, expected)
  end

  def contato_json(ct)
    {
      id: ct.id, name: ct.name, phone: ct.phone, jid: ct.jid, user_id: ct.user_id,
      carteira: ct.custom_attributes&.dig('gerente_jueri_nome'), id_jueri: ct.try(:id_jueri),
      created_at: ct.created_at, telefones_extra: ct.reseller_phones.pluck(:phone),
      conversas: ct.conversations.includes(:inbox).map { |c| conversa_json(c) }
    }
  end

  def conversa_json(c)
    msgs = c.messages
    {
      conversa: c.id, caixa: c.inbox&.name, atendente_user_id: c.user_id, status: c.status,
      criada: c.created_at, msgs: msgs.count,
      primeira_msg: msgs.minimum(:created_at), ultima_msg: msgs.maximum(:created_at)
    }
  end
end
