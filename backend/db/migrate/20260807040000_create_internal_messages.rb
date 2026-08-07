# Chat interno entre a equipe (consultor <-> gerente <-> financeiro <-> diretoria)
# — diferente de "conversas" (que são sempre com uma revendedora via WhatsApp).
# Confusão real do usuário: "Chats da equipe" parecia ser isso, mas era só um
# filtro de conversas de WhatsApp atribuídas a outro colega. Isso aqui é
# mensagem direta de verdade, sem WhatsApp envolvido, 1-a-1 entre dois usuários.
class CreateInternalMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :internal_messages do |t|
      t.bigint :account_id, null: false
      t.bigint :sender_id, null: false
      t.bigint :recipient_id, null: false
      t.text :text, null: false
      t.datetime :read_at
      t.timestamps
    end

    add_index :internal_messages, :account_id
    add_index :internal_messages, [:sender_id, :recipient_id]
    add_index :internal_messages, [:recipient_id, :sender_id]
    add_index :internal_messages, [:recipient_id, :read_at]
    add_foreign_key :internal_messages, :accounts
    add_foreign_key :internal_messages, :users, column: :sender_id
    add_foreign_key :internal_messages, :users, column: :recipient_id
  end
end
