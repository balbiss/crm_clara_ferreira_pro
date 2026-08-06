class AccountsController < ApplicationController
  before_action :authenticate_user!
  # Configuração da conta (nome, etc.) é "configuração crítica"
  # (briefing seção 30, exclusiva de Diretoria) — antes qualquer
  # usuário autenticado (inclusive consultor) conseguia ler/alterar isso.
  before_action :require_owner!, only: %i[ show update ]

  def show
    account = current_user.account
    render json: {
      account_name:        account.name,
      email:               current_user.email,
      subscription_status: account.subscription_status || 'pending',
      trial_ends_at:       account.trial_ends_at,
      plan_name:           'Plano Premium',
      facebook_page_name:  account.facebook_page_name
    }
  end

  def update
    account = current_user.account
    if account.update(account_params)
      render json: { message: 'Configurações atualizadas com sucesso!' }, status: :ok
    else
      render json: { error: account.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update_password
    if current_user.update_with_password(password_params)
      # Ao trocar a senha, o Devise desloga o usuário, então precisamos re-logar:
      bypass_sign_in(current_user)
      render json: { message: 'Senha alterada com sucesso!' }, status: :ok
    else
      render json: { error: current_user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:account).permit(:name)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
