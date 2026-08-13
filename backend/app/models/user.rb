class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  belongs_to :account, optional: true
  belongs_to :round_robin_group, optional: true

  has_many :notes, dependent: :destroy
  has_many :contacts, dependent: :nullify
  has_many :tarefas, dependent: :nullify
  has_many :agendamentos, dependent: :destroy
  has_many :conversations, dependent: :nullify
  has_many :push_subscriptions, dependent: :destroy
  has_many :inbox_members, dependent: :destroy
  has_many :assigned_inboxes, through: :inbox_members, source: :inbox
  has_many :sales_team_memberships, dependent: :destroy
  has_many :sales_teams, through: :sales_team_memberships
  has_one_attached :avatar

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  # Os 4 perfis do briefing da Clara Ferreira (seção 30). Os herdados do fork da
  # VisitaIA (atendente/empresa/admin) foram removidos — ver migration
  # RemapLegacyUserRoles pro remapeamento dos valores antigos.
  enum :role, {
    consultor: 0, gerente: 1, diretoria: 2, financeiro: 3
  }

  OWNER_LEVEL_ROLES = %w[gerente diretoria].freeze
  FINANCE_ROLES = %w[financeiro diretoria].freeze

  def active_for_authentication?
    super && status == 'active'
  end

  def inactive_message
    status == 'active' ? super : :account_inactive
  end

  # Helpers for permissions JSON
  def has_permission?(key)
    permissions.present? && permissions[key.to_s] == true
  end

  def owner_level?
    OWNER_LEVEL_ROLES.include?(role)
  end

  def finance_access?
    FINANCE_ROLES.include?(role)
  end

  # IDs de "revendedor líder" (times de vendas do Jueri, ex: "Vendas 4") cuja
  # carteira inteira esse usuário pode ver — além da atribuição direta
  # (Contact#user_id) e do mapeamento legado 1:1 (jueri_gerente_id). Usado nos
  # visible_*_scope dos controllers pra expandir a carteira visível.
  def accessible_jueri_lider_ids
    sales_teams.pluck(:jueri_lider_id)
  end

  # Foto de perfil (cada usuário troca a própria, ver ProfileController) —
  # calculado aqui (não numa coluna) pra ser reaproveitado em todo lugar que
  # serializa um User: login, /agents, threads do chat interno.
  def avatar_url
    return nil unless avatar.attached?
    Rails.application.routes.url_helpers.rails_storage_proxy_url(avatar, host: ENV.fetch('API_HOST', 'http://localhost:3000'))
  end
end
