# Configurações da PRÓPRIA conta do usuário logado (diferente de
# AgentsController, que é a diretoria gerenciando OUTROS usuários). Qualquer
# perfil pode trocar a própria foto, sem precisar de permissão especial —
# é dado pessoal, não configuração crítica do sistema.
class ProfileController < ApplicationController
  before_action :authenticate_user!

  # PATCH /profile/avatar
  def update_avatar
    unless params[:avatar].present?
      return render json: { error: 'Nenhuma imagem enviada.' }, status: :unprocessable_entity
    end

    current_user.avatar.attach(params[:avatar])
    render json: { avatar_url: current_user.avatar_url }
  end

  # DELETE /profile/avatar — remove a foto, volta pras iniciais coloridas
  def destroy_avatar
    current_user.avatar.purge
    render json: { avatar_url: nil }
  end
end
