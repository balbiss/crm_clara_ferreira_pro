# Pipeline customizável (ex: Varejo, Onboarding, Atacado, Prospecção — espelhando o
# Kommo que a Clara Ferreira já usava). Diferente do Consignado (que usa a régua
# automática em Contact#status e não passa por aqui), esses pipelines são genéricos:
# a empresa cria, renomeia e apaga livremente, e os contatos entram/saem manualmente.
class Pipeline < ApplicationRecord
  belongs_to :account
  has_many :pipeline_stages, -> { order(:position) }, dependent: :destroy
  has_many :pipeline_cards, dependent: :destroy

  before_validation :generate_slug, on: :create
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }

  private

  def generate_slug
    return if slug.present?
    base = name.to_s.parameterize
    candidate = base
    n = 2
    while account.pipelines.exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end
end
