# Telefone adicional de uma revendedora (mãe, sócia, número comercial etc. —
# briefing seção 7). Substitui custom_attributes["telefones_adicionais"]
# (jsonb) por uma tabela relacional indexável de verdade.
class ResellerPhone < ApplicationRecord
  belongs_to :contact

  validates :phone, presence: true, uniqueness: { scope: :contact_id }
end
