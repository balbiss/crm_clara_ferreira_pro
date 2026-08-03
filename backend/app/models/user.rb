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

  # Perfis herdados da VisitaIA (atendente/empresa/admin) + os 4 do briefing da Clara
  # Ferreira (consultor/gerente/diretoria/financeiro, seção 30). Adição aditiva só no
  # model — os checks de autorização espalhados pelos controllers (`role == 'admin' ||
  # role == 'empresa'`) ainda não foram atualizados pra reconhecer os novos, use
  # `owner_level?`/`finance_access?` abaixo em código NOVO em vez de comparar role direto.
  enum :role, {
    atendente: 0, empresa: 1, admin: 2,
    consultor: 3, gerente: 4, diretoria: 5, financeiro: 6
  }

  OWNER_LEVEL_ROLES = %w[empresa admin gerente diretoria].freeze
  FINANCE_ROLES = %w[financeiro diretoria admin empresa].freeze

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
    OWNER_LEVEL_ROLES.include?(role) || has_permission?('admin')
  end

  def finance_access?
    FINANCE_ROLES.include?(role) || has_permission?('admin')
  end
end
