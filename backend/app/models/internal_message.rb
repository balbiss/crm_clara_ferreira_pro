# Mensagem direta entre dois membros da equipe (consultor/gerente/financeiro/
# diretoria) — chat interno do CRM, sem relação nenhuma com WhatsApp/revendedora.
class InternalMessage < ApplicationRecord
  belongs_to :account
  belongs_to :sender, class_name: 'User'
  belongs_to :recipient, class_name: 'User'

  validates :text, presence: true

  scope :between, ->(user_a_id, user_b_id) {
    where(sender_id: user_a_id, recipient_id: user_b_id)
      .or(where(sender_id: user_b_id, recipient_id: user_a_id))
  }
end
