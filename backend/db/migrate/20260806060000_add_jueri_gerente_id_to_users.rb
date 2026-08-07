# Mapeamento explícito: a Clara vai passar o ID de cada gerente/consultora
# no Jueri (campo `gerente` do cadastro de revendedor) pra gente casar com o
# usuário certo aqui no CRM. Diferente de rodízio automático (rejeitado
# antes) — aqui a revendedora nova cai direto pra quem JÁ é a responsável
# dela de verdade no Jueri, sem sorteio nenhum.
class AddJueriGerenteIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :jueri_gerente_id, :string
    add_index :users, [:account_id, :jueri_gerente_id]
  end
end
