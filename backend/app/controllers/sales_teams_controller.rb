# Gestão de acesso aos "times de vendas" do Jueri (Vendas 1, Vendas 4 etc) —
# quem além do responsável direto (Contact#user_id) pode ver a carteira
# inteira de um time. Restrito a gerência/diretoria (briefing seção 30).
# Ver SalesTeam, JueriSyncService#sincronizar_times_de_vendas.
class SalesTeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_full_portfolio!
  before_action :set_sales_team, only: [:update_members, :assign_unassigned]

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

  # POST /sales_teams/:id/assign_unassigned { user_id: X }
  # Atribui como responsável (Contact#user_id) todas as revendedoras deste
  # time que AINDA NÃO TÊM responsável — usa o mesmo vínculo com o Jueri
  # (custom_attributes['gerente_jueri_id'] == fk_revendedor_gerente_id) já
  # usado pra "Gerenciar acesso". Só preenche quem está sem responsável:
  # não sobrescreve nenhuma atribuição manual já feita antes (decisão do
  # briefing — revendedora sincronizada entra sem responsável, o gerente
  # atribui; isso aqui só torna essa atribuição inicial mais rápida,
  # em massa, pelo time certo em vez de uma por uma).
  def assign_unassigned
    user = current_user.account.users.find_by(id: params[:user_id])
    return render json: { error: 'user_not_found', message: 'Usuário não encontrado.' }, status: :unprocessable_entity unless user

    count = unassigned_scope(@sales_team).update_all(user_id: user.id)

    render json: { assigned_count: count, team: serialize(@sales_team) }
  end

  private

  def set_sales_team
    @sales_team = current_user.account.sales_teams.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Time de vendas não encontrado.' }, status: :not_found
  end

  def unassigned_scope(team)
    current_user.account.contacts
      .where(user_id: nil)
      .where("custom_attributes ->> 'gerente_jueri_id' = ?", team.jueri_lider_id)
  end

  def serialize(team)
    {
      id: team.id,
      jueri_lider_id: team.jueri_lider_id,
      nome: team.nome,
      users: team.users.map { |u| { id: u.id, name: "#{u.first_name} #{u.last_name}".strip, role: u.role, avatar_url: u.avatar_url } },
      unassigned_contacts_count: unassigned_scope(team).count
    }
  end
end
