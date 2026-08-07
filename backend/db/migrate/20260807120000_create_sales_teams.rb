# "Times de vendas" do Jueri (revendedor com fk_tipo_revendedor_id=1, ex:
# "Vendas 1", "Vendas 4") — não é uma pessoa, é o agrupamento/carteira que
# várias revendedoras normais apontam via fk_revendedor_gerente_id. Ver
# JueriSyncService, que já excluía esses registros de virar Contact e agora
# também os cataloga aqui (mesma chamada em lote, sem custo extra de API).
class CreateSalesTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :sales_teams do |t|
      t.references :account, null: false, foreign_key: true
      t.string :jueri_lider_id, null: false
      t.string :nome, null: false

      t.timestamps
    end

    add_index :sales_teams, [:account_id, :jueri_lider_id], unique: true, name: 'index_sales_teams_on_account_and_lider_id'

    # Quem, além do responsável direto (User.jueri_gerente_id, mapeamento 1:1
    # já existente), pode ver a carteira inteira de um time — múltiplos
    # operadores por time, igual ao "gerenciar agendas" do próprio Jueri.
    create_table :sales_team_memberships do |t|
      t.references :sales_team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :sales_team_memberships, [:sales_team_id, :user_id], unique: true, name: 'index_sales_team_memberships_uniq'
  end
end
