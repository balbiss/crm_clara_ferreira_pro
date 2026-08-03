class AddSnapshotFieldsToContacts < ActiveRecord::Migration[8.1]
  def change
    # Snapshot pré-calculado (requisito de performance <200ms) — o Worker de
    # sync (próxima fase) grava aqui o agregado já calculado, pra tela de
    # Carteira Ativa nunca precisar somar pedidos em tempo real por linha.
    # Time Travel continua consultando `pedidos` direto (esses campos só
    # cacheiam o estado ATUAL, não servem pra datas passadas).
    add_column :contacts, :pecas_abertas_atual, :integer, null: false, default: 0
    add_column :contacts, :pedidos_abertos_count, :integer, null: false, default: 0
    add_column :contacts, :snapshot_calculado_em, :datetime

    add_index :contacts, :pecas_abertas_atual
  end
end
