class AddJueriWebhookTokenToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :jueri_webhook_token, :string
    add_index :accounts, :jueri_webhook_token, unique: true
  end
end
