class RemoveRealEstateLeftovers < ActiveRecord::Migration[8.1]
  def change
    drop_table :appointments do |t|
      t.bigint "account_id", null: false
      t.date "appointment_date"
      t.string "broker_name"
      t.bigint "condominium_id"
      t.bigint "contact_id", null: false
      t.datetime "created_at", null: false
      t.string "end_time"
      t.bigint "property_id"
      t.string "start_time"
      t.string "status"
      t.datetime "updated_at", null: false
      t.bigint "user_id"
    end

    drop_table :properties
    drop_table :condominia

    remove_column :contacts, :profession, :string
    remove_column :contacts, :gross_income, :decimal
    remove_column :contacts, :down_payment, :decimal
    remove_column :contacts, :fgts_balance, :decimal
    remove_column :contacts, :dependents, :integer

    remove_column :accounts, :portal_token, :string
  end
end
