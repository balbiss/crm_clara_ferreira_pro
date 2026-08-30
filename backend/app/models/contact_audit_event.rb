# Trilha de auditoria de mudanças de Contact — histórico de transferência de
# responsável (briefing seção 22) e de mudança de status. Criado
# automaticamente via callback no Contact (ver Contact#registrar_mudanca_*),
# nunca instanciado à mão fora dali.
class ContactAuditEvent < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :changed_by, class_name: 'User', optional: true

  TIPOS = %w[responsavel status].freeze
  validates :event_type, inclusion: { in: TIPOS }

  scope :do_tipo, ->(tipo) { where(event_type: tipo) }
end
