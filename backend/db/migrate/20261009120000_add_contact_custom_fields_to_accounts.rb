# Campos novos do painel de contato criados pela própria dona (ex: grupo
# "Produtos" com "Mais vende" / "Precisa ter na maleta", pedido 2026-10-09).
# Só a definição (chave + nome) fica aqui; o valor de cada revendedora vai em
# contacts.custom_attributes, igual aos 13 campos fixos.
class AddContactCustomFieldsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :contact_custom_fields, :jsonb, null: false, default: []
  end
end
