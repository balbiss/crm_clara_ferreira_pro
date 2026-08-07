# "Nível" da revendedora no Jueri (Consignado/Colaborador/Caução/Safira/Rubi/
# Esmeralda/Diamante) — vem pronto (já resolvido, sem custo de API extra) no
# campo `level_revendedor` da listagem em lote /revendedor. Coluna dedicada
# (não custom_attributes) porque vai ser filtro de verdade na tela de Acertos
# (fase de Agendamento), não só exibição.
class AddNivelToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :nivel, :string
    add_index :contacts, [:account_id, :nivel]
  end
end
