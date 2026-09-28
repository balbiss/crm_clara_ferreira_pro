class CreateMessageTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :message_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :nome, null: false
      t.string :categoria
      t.text :mensagem, null: false

      t.timestamps
    end
  end
end
