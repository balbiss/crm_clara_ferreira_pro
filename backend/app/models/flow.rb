# "Fluxos" — construtor visual de automação de conversa (MVP). Container do
# grafo de nós+conexões, mesma ideia de Pipeline (que agrupa PipelineStage),
# só que aqui a topologia é livre em vez de etapas lineares.
class Flow < ApplicationRecord
  belongs_to :account
  # Caixa de WhatsApp/Instagram em que o gatilho por palavra-chave escuta —
  # sem isso, um fluxo disparava em QUALQUER caixa da conta (achado num
  # teste real: risco de um fluxo de teste responder num cliente de
  # verdade). Opcional pra não quebrar fluxo antigo sem caixa definida
  # ainda, mas nesse caso ele simplesmente não dispara em lugar nenhum
  # (ver FlowRunnerService.trigger_by_keyword).
  belongs_to :inbox, optional: true
  has_many :flow_nodes, dependent: :destroy
  has_many :flow_edges, dependent: :destroy
  has_many :flow_runs, dependent: :destroy

  validates :name, presence: true
end
