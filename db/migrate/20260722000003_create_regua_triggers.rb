class CreateReguaTriggers < ActiveRecord::Migration[8.1]
  def change
    create_table :regua_triggers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :status, null: false
      t.string :action_type, null: false
      t.jsonb :config, null: false, default: {}
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :regua_triggers, [:account_id, :status]
  end
end
