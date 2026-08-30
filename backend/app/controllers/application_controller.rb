class ApplicationController < ActionController::API
  before_action :set_current_actor

  private

  # Deixa Current.user disponível pra Contact#registrar_mudanca_* saber quem
  # fez uma mudança de status/responsável, sem precisar passar isso por
  # parâmetro em cada update. current_user vem do Devise/Warden e já está
  # resolvido nesse ponto independente da ordem dos before_action de cada
  # controller filho (authenticate_user! só bloqueia quando ausente, não é
  # pré-requisito pra current_user existir).
  def set_current_actor
    Current.user = current_user
  end

  # Três níveis de autorização usados pelos controllers filhos (briefing seção 30):
  #
  # 1. owner?            → configurações críticas do sistema (só diretoria).
  #                        Gerente NÃO entra aqui — ele acompanha a operação, mas não
  #                        mexe em config (agentes, inboxes, tags, cobrança, conta).
  # 2. full_portfolio?   → enxerga a carteira INTEIRA (todas as revendedoras, de todos
  #                        os consultores), não só a própria. Gerente + Diretoria.
  # 3. finance?          → acessa dados financeiros/cobrança (Financeiro + Diretoria).
  #
  # Consultor não entra em nenhum dos três — só vê/edita a própria carteira
  # (ver escopo em ContactsController#index e #set_contact).

  def require_owner!
    unless owner?
      render json: { error: 'forbidden', message: 'Acesso restrito à diretoria/administração.' }, status: :forbidden
    end
  end

  def require_full_portfolio!
    unless full_portfolio?
      render json: { error: 'forbidden', message: 'Acesso restrito a gerência/diretoria.' }, status: :forbidden
    end
  end

  def require_finance!
    unless finance?
      render json: { error: 'forbidden', message: 'Acesso restrito ao financeiro/diretoria.' }, status: :forbidden
    end
  end

  def owner?
    current_user&.diretoria?
  end

  def full_portfolio?
    current_user&.owner_level?
  end

  def finance?
    current_user&.finance_access?
  end

  # Escopo de leitura por perfil (briefing seção 22/30) — movido de
  # ContactsController pra cá pra ser reaproveitado por qualquer controller
  # aninhado em /contacts/:contact_id/* (ex: ContactTagsController) sem
  # duplicar a regra de isolamento de carteira:
  # - full_portfolio (gerente/diretoria) e finance (financeiro) veem a
  #   carteira inteira — financeiro precisa disso pra Inativas/cobrança
  #   cruzarem consultores.
  # - Consultor só vê a própria carteira (contact.user_id == self).
  def visible_contacts_scope
    base = current_user.account.contacts
    if full_portfolio? || finance? || current_user.permissions&.dig('view_all_contacts')
      base
    else
      lider_ids = current_user.accessible_jueri_lider_ids
      if lider_ids.any?
        base.where(user_id: current_user.id)
          .or(base.where("custom_attributes ->> 'gerente_jueri_id' IN (?)", lider_ids))
      else
        base.where(user_id: current_user.id)
      end
    end
  end
end
