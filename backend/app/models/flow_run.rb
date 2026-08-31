# Estado de uma execução de Fluxo em andamento numa conversa — existe pra
# suportar nós que precisam PARAR e esperar a próxima mensagem do contato
# (Perguntar, Botões/Lista). `current_node_key` é o nó onde parou;
# `variables` guarda o que já foi capturado.
class FlowRun < ApplicationRecord
  belongs_to :flow
  belongs_to :conversation
  belongs_to :contact

  STATUSES = %w[running waiting_reply completed].freeze
  validates :status, inclusion: { in: STATUSES }
end
