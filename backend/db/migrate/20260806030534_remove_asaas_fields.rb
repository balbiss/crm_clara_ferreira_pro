class RemoveAsaasFields < ActiveRecord::Migration[8.1]
  def change
    remove_index  :contacts, :asaas_customer_id
    remove_column :contacts, :asaas_customer_id, :string
    remove_column :accounts, :asaas_api_key, :string
    remove_column :accounts, :asaas_sandbox, :boolean, default: false, null: false
  end
end
