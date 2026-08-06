class ApplicationController < ActionController::API
  private

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
end
