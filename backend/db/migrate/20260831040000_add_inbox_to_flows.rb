class AddInboxToFlows < ActiveRecord::Migration[8.1]
  def change
    # Sem isso, o gatilho por palavra-chave de um Fluxo disparava em
    # QUALQUER caixa de WhatsApp da conta (achado pelo próprio usuário
    # testando: "não tem como escolher qual caixa") — risco real de um
    # fluxo de teste responder num número de cliente de verdade.
    add_reference :flows, :inbox, null: true, foreign_key: true
  end
end
