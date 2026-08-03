class CreatePipelines < ActiveRecord::Migration[8.1]
  def change
    create_table :pipelines do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, default: 0, null: false
      t.boolean :system, default: false, null: false

      t.timestamps
    end
    add_index :pipelines, [:account_id, :slug], unique: true

    create_table :pipeline_stages do |t|
      t.references :pipeline, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, default: '#d49ba7'
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    create_table :pipeline_cards do |t|
      t.references :pipeline, null: false, foreign_key: true
      t.references :pipeline_stage, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    add_index :pipeline_cards, [:pipeline_id, :contact_id], unique: true
  end
end
