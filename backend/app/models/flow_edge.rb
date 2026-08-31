# Conexão entre dois FlowNode (por `key`, não id do Rails). source_handle/
# target_handle identificam qual saída/entrada nomeada quando o nó tem mais
# de uma (ex: ConditionNode tem as saídas "sim"/"nao").
class FlowEdge < ApplicationRecord
  belongs_to :flow

  validates :source_key, :target_key, presence: true
end
