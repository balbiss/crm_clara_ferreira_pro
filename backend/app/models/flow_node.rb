# Nó do editor visual de Fluxos. `key` (não o id do Rails) é o identificador
# que o Vue Flow usa e que FlowEdge#source_key/target_key referenciam —
# gerado no frontend na criação, nunca muda.
#
# node_type é string livre de propósito (não enum Rails): permite adicionar
# tipo novo (webhook, add_tag, assign_agent...) só criando o componente Vue
# correspondente, sem migration. `data` guarda a configuração de cada tipo —
# mesmo padrão de PipelineTrigger#config, pensado pra um dia ser executado
# por um runner parecido com PipelineTriggerRunnerService.
class FlowNode < ApplicationRecord
  belongs_to :flow

  NODE_TYPES = %w[trigger send_message condition wait end].freeze

  validates :key, presence: true, uniqueness: { scope: :flow_id }
  validates :node_type, presence: true, inclusion: { in: NODE_TYPES }
end
