# Feed de atividade genérico pra todo evento recebido do webhook da Jueri —
# ver Webhooks::JueriController#registrar_atividade. Só consulta, sem
# notificação/push (diferente de Notification, usado só pra revendedor.created).
class JueriActivity < ApplicationRecord
  belongs_to :account
  belongs_to :contact, optional: true
end
