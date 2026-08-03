class AddIdJueriToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :id_jueri, :string
    add_column :contacts, :jueri_synced_at, :datetime
    add_index :contacts, [:account_id, :id_jueri], unique: true
  end
end
