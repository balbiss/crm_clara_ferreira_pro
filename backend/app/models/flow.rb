# "Fluxos" — construtor visual de automação de conversa (MVP). Container do
# grafo de nós+conexões, mesma ideia de Pipeline (que agrupa PipelineStage),
# só que aqui a topologia é livre em vez de etapas lineares.
class Flow < ApplicationRecord
  belongs_to :account
  has_many :flow_nodes, dependent: :destroy
  has_many :flow_edges, dependent: :destroy

  validates :name, presence: true
end
