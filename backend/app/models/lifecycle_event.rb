# Marco histórico do ciclo de vida da revendedora (revendedoras-ativas-criterios.md).
# Diferente do status atual (contacts.status, sobrescrito a cada transição),
# isso é um REGISTRO — permite reconstruir "quantas vezes ela deu Churn",
# "quando foi Iniciada pela 1a vez", etc.
class LifecycleEvent < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :pedido, optional: true

  TIPOS = %w[iniciada churn reativacao].freeze
  validates :event_type, inclusion: { in: TIPOS }
  validates :occurred_at, presence: true

  # "Iniciada" só pode acontecer 1x na vida da revendedora — reforçado também
  # por índice único parcial no banco (idx_lifecycle_events_iniciada_unica).
  validate :iniciada_unica_por_revendedora, if: -> { event_type == 'iniciada' }

  scope :do_tipo, ->(tipo) { where(event_type: tipo) }

  private

  def iniciada_unica_por_revendedora
    return unless LifecycleEvent.where(contact_id: contact_id, event_type: 'iniciada').where.not(id: id).exists?
    errors.add(:event_type, "já existe evento 'iniciada' pra essa revendedora — só pode ocorrer uma vez na vida dela")
  end
end
