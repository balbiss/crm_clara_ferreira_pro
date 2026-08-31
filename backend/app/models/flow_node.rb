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

  # Arquivo do nó "Enviar mídia" quando enviado por upload direto (em vez de
  # colar uma URL externa) — mesmo padrão de Message#attachment. Achado num
  # teste real: mandar por URL externa deu 500 na WAHA (não é confiável),
  # upload direto reaproveita o caminho que já funciona de verdade
  # (WhatsappWahaService#send_message com anexo, base64).
  has_one_attached :media

  # Alguns tipos do prompt original viraram data.subtype dentro de um único
  # node_type (ex: 4 "enviar mídia" e "botões"/"lista" viram send_media/
  # options com um campo dentro; "verificar X" do prompt vira condition com
  # data.check_type) em vez de 1 node_type por bullet — evita inflar o
  # schema e a paleta com N variações quase idênticas.
  NODE_TYPES = %w[trigger send_message ask_question send_media options condition wait action end].freeze

  validates :key, presence: true, uniqueness: { scope: :flow_id }
  validates :node_type, presence: true, inclusion: { in: NODE_TYPES }
end
