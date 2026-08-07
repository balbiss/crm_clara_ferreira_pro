# Gestão de acesso aos "times de vendas" do Jueri (Vendas 1, Vendas 4 etc) —
# quem além do responsável direto (Contact#user_id) pode ver a carteira
# inteira de um time. Restrito a gerência/diretoria (briefing seção 30).
# Ver SalesTeam, JueriSyncService#sincronizar_times_de_vendas.
class SalesTeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_full_portfolio!
  before_action :set_sales_team, only: [:update_members]

  def index
    teams = current_user.account.sales_teams.includes(:users).order(:nome)
    render json: teams.map { |t| serialize(t) }
  end

  # PATCH /sales_teams/:id/members { user_ids: [1, 2, 3] }
  # Substitui a lista inteira de membros do time (mais simples que
  # add/remove individual pra essa tela).
  def update_members
    user_ids = Array(params[:user_ids]).map(&:to_i)
    users = current_user.account.users.where(id: user_ids)

    ActiveRecord::Base.transaction do
      @sales_team.sales_team_memberships.destroy_all
      users.each { |u| @sales_team.sales_team_memberships.create!(user: u) }
    end

    render json: serialize(@sales_team.reload)
  end

  private

  def set_sales_team
    @sales_team = current_user.account.sales_teams.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Time de vendas não encontrado.' }, status: :not_found
  end

  def serialize(team)
    {
      id: team.id,
      jueri_lider_id: team.jueri_lider_id,
      nome: team.nome,
      users: team.users.map { |u| { id: u.id, name: "#{u.first_name} #{u.last_name}".strip, role: u.role, avatar_url: u.avatar_url } }
    }
  end
end
