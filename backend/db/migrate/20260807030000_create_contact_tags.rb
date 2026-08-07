# Etiquetas hoje só existem em Conversation (conversation_tags) — mas o botão
# "+ etiqueta" no cadastro da revendedora (ContactDetails.vue) precisa marcar
# a REVENDEDORA, não uma conversa específica (muita revendedora sincronizada
# do Jueri ainda não trocou nenhuma mensagem, não teria onde pendurar a tag).
# Mesmo desenho de conversation_tags, só que pendurado em Contact.
class CreateContactTags < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_tags do |t|
      t.bigint :contact_id, null: false
      t.bigint :tag_id, null: false
    end

    add_index :contact_tags, [:contact_id, :tag_id], unique: true, name: 'index_contact_tags_on_contact_and_tag'
    add_index :contact_tags, :contact_id
    add_index :contact_tags, :tag_id
    add_foreign_key :contact_tags, :contacts
    add_foreign_key :contact_tags, :tags
  end
end
