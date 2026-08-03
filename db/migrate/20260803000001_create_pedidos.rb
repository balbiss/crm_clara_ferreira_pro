class CreatePedidos < ActiveRecord::Migration[8.1]
  def change
    create_table :pedidos do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true

      # ID do pedido no Jueri — chave de upsert na sincronização (Worker, fase 2).
      t.string :jueri_pedido_id, null: false

      t.date :data_criacao, null: false
      t.date :data_baixa
      t.date :data_cancelamento

      # status_id do Jueri: 1-Aberto, 2-Baixado, 3-Cancelado, 4-Perdido
      t.integer :status_id, null: false

      # Qtd. Final (pós-baixa) e Qtd. Inicial (preservada no momento da baixa).
      # Regra de negócio (revendedoras-ativas-criterios.md): usar
      # quantidade_antes_baixa quando > 0, com fallback pra quantidade.
      t.integer :quantidade, null: false, default: 0
      t.integer :quantidade_antes_baixa

      t.decimal :valor_total, precision: 12, scale: 2

      t.timestamps
    end

    # Upsert idempotente por pedido do Jueri (um pedido nunca pertence a duas contas).
    add_index :pedidos, :jueri_pedido_id, unique: true

    # Índice composto pedido pelo Tech Lead: acelera tanto o cálculo "ativa hoje"
    # quanto o Time Travel ("estava aberto em D?"), que filtra por contact_id e
    # compara as 3 datas + status_id.
    add_index :pedidos, [:contact_id, :data_criacao, :data_baixa, :status_id],
      name: "idx_pedidos_ciclo_vida"

    # Índice parcial — cobre o caso mais comum e mais quente (pedidos em aberto
    # AGORA, sem baixa) sem carregar as linhas já baixadas/canceladas no índice.
    add_index :pedidos, :contact_id, where: "data_baixa IS NULL", name: "idx_pedidos_abertos"
  end
end
