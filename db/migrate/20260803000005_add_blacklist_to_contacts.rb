class AddBlacklistToContacts < ActiveRecord::Migration[8.1]
  def change
    # Blacklist manual ("Rev. Desconsiderados") — exclusão automática das
    # listas de Ativas/Inativas independente do que o Jueri diga sobre pedidos
    # em aberto. Override manual, só quem enxerga a carteira toda ou financeiro
    # pode marcar (gate aplicado em ContactsController#contact_params).
    add_column :contacts, :desconsiderado, :boolean, null: false, default: false
    add_column :contacts, :desconsiderado_at, :datetime
    add_column :contacts, :desconsiderado_motivo, :string

    add_index :contacts, [:account_id, :desconsiderado]
  end
end
