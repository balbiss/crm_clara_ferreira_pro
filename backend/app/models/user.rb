class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  belongs_to :account, optional: true
  belongs_to :round_robin_group, optional: true

  has_many :support_tickets
  has_many :support_ticket_messages, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :contacts, dependent: :nullify
  has_many :tarefas, dependent: :nullify
  has_many :conversations, dependent: :nullify
  has_many :push_subscriptions, dependent: :destroy
  has_many :inbox_members, dependent: :destroy
  has_many :assigned_inboxes, through: :inbox_members, source: :inbox

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
end
