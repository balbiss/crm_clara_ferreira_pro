class CreatePipelineTriggers < ActiveRecord::Migration[8.1]
  def change
    create_table :pipeline_triggers do |t|
      t.references :pipeline_stage, null: false, foreign_key: true
      t.string :action_type, null: false
      t.jsonb :config, null: false, default: {}
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
