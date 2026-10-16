class AddUserIdToMessageTemplates < ActiveRecord::Migration[8.1]
  def change
    # nil = modelo geral (todo mundo da empresa usa); preenchido = modelo
    # individual, só o dono vê ("Meus modelos").
    add_reference :message_templates, :user, null: true, foreign_key: true, index: true
  end
end
