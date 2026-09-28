class CreateContactFieldGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_field_groups do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.jsonb :field_keys, null: false, default: []

      t.timestamps
    end
  end
end
