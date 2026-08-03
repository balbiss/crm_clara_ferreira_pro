class CreateResellerPhones < ActiveRecord::Migration[8.1]
  def change
    # Substitui o jsonb custom_attributes["telefones_adicionais"] por uma tabela
    # relacional de verdade — o jsonb não é indexável por igualdade de forma
    # eficiente (a busca antiga usava containment `@>`, que não usa índice sem
    # GIN dedicado). Aqui a busca é um índice B-Tree comum em `phone`.
    create_table :reseller_phones do |t|
      t.references :contact, null: false, foreign_key: true
      t.string :phone, null: false
      t.string :label # "Mãe", "Sócia", "Telefone comercial" etc.

      t.timestamps
    end

    add_index :reseller_phones, :phone
    add_index :reseller_phones, [:contact_id, :phone], unique: true
  end
end
