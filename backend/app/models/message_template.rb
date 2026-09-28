class MessageTemplate < ApplicationRecord
  belongs_to :account
  has_one_attached :attachment

  validates :nome, presence: true
  # Modelo pode ser só áudio/anexo, sem texto nenhum (pedido 2026-09-28:
  # "como faço pra colocar como modelo um áudio?") -- só exige texto quando
  # não tem anexo nenhum.
  validates :mensagem, presence: true, unless: -> { attachment.attached? }

  scope :ordered, -> { order(:nome) }

  def attachment_url
    return nil unless attachment.attached?
    Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment, host: ENV.fetch('API_HOST', 'http://localhost:3000'))
  end

  def attachment_type
    attachment.attached? ? attachment.content_type : nil
  end
end
