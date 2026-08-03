class AddMinPecasAtivaToAccounts < ActiveRecord::Migration[8.1]
  def change
    # Antes era a constante ATIVACAO_MINIMO_PECAS = 25 fixa em JueriSyncService.
    # Configurável por conta agora (revendedoras-ativas-criterios.md: "O limiar
    # min_pecas_ativa é configurável em Parâmetros do Sistema").
    add_column :accounts, :min_pecas_ativa, :integer, null: false, default: 25
  end
end
