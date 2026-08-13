class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :inboxes, dependent: :destroy
  has_many :round_robin_groups, dependent: :destroy
  has_many :pipelines, dependent: :destroy
  has_many :regua_triggers, dependent: :destroy
  has_many :pedidos, dependent: :destroy
  has_many :lifecycle_events, dependent: :destroy
  has_many :tarefas, dependent: :destroy
  has_many :sales_teams, dependent: :destroy
  has_many :agendamentos, dependent: :destroy

  before_create :set_trial_period
  before_create :generate_jueri_webhook_token

  def active_subscription?
    return false if ['blocked', 'canceled', 'unpaid'].include?(subscription_status)
    subscription_status == 'active' || (trial_ends_at.present? && trial_ends_at > Time.current)
  end

  private

  def set_trial_period
    self.trial_ends_at ||= 7.days.from_now
  end

  def generate_jueri_webhook_token
    self.jueri_webhook_token ||= SecureRandom.hex(20)
  end
end
