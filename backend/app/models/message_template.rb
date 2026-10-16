class MessageTemplate < ApplicationRecord
  belongs_to :account
  # user_id nil = modelo GERAL (todo mundo da empresa usa, só diretoria
  # administra); preenchido = modelo INDIVIDUAL ("Meus modelos"), só o dono
  # vê, usa e edita (pedido da Clara, 2026-10-16).
  belongs_to :user, optional: true
  has_one_attached :attachment

  validates :nome, presence: true
  # Modelo pode ser só áudio/anexo, sem texto nenhum (pedido 2026-09-28:
  # "como faço pra colocar como modelo um áudio?") -- só exige texto quando
  # não tem anexo nenhum.
  validates :mensagem, presence: true, unless: -> { attachment.attached? }

  scope :ordered, -> { order(:nome) }
  scope :visible_to, ->(user) { where(user_id: nil).or(where(user_id: user.id)) }

  def geral?
    user_id.nil?
  end

  def attachment_url
    return nil unless attachment.attached?
    Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment, host: ENV.fetch('API_HOST', 'http://localhost:3000'))
  end

  def attachment_type
    attachment.attached? ? attachment.content_type : nil
  end
end
