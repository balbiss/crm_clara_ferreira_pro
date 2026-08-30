class Inbox < ApplicationRecord
  belongs_to :account
  belongs_to :round_robin_group, optional: true
  has_many :conversations, dependent: :nullify
  has_many :inbox_members, dependent: :destroy
  has_many :users, through: :inbox_members, dependent: :destroy

  validate :followup_not_allowed_for_instagram
  # Baileys e WAHA derivam o nome da sessão externa a partir do phone_number
  # (ver WhatsappBaileysService/WhatsappWahaService) — duas caixas com o
  # mesmo número acabam disputando a MESMA conexão/sessão externa, e só uma
  # recebe o webhook de verdade (aconteceu de fato com um duplo clique na
  # criação). Trava aqui, não só no frontend.
  validates :phone_number, uniqueness: { scope: :account_id },
                            if: -> { provider.in?(%w[baileys waha]) && phone_number.present? }

  def messaging_service
    case provider
    when 'instagram' then InstagramMessagingService.new(self)
    when 'waha' then WhatsappWahaService.new(self)
    else WhatsappBaileysService.new(self)
    end
  end

  private

  def followup_not_allowed_for_instagram
    return unless provider == 'instagram' && followup_enabled?

    errors.add(:followup_enabled, 'não é permitido para o canal Instagram (janela de 24h da Meta)')
  end
end
