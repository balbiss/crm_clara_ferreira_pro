# Time de vendas do Jueri (revendedor com fk_tipo_revendedor_id=1, ex: "Vendas
# 4") — catalogado pelo JueriSyncService a cada sync. Não é uma pessoa: é o
# agrupamento/carteira que revendedoras normais apontam via
# fk_revendedor_gerente_id (guardado em Contact#custom_attributes['gerente_jueri_id']).
class SalesTeam < ApplicationRecord
  belongs_to :account
  has_many :sales_team_memberships, dependent: :destroy
  has_many :users, through: :sales_team_memberships
end
