class AddClientReplyTriggerEvent < ActiveRecord::Migration[8.1]
  def change
    # Quando o gatilho dispara: 'enter' (o lead entra na etapa — o único modo que
    # existia) ou 'client_reply' (o cliente responde estando na etapa). Os
    # gatilhos que já existem continuam 'enter'.
    add_column :pipeline_triggers, :event, :string, null: false, default: 'enter'

    # Marca que o gatilho de "cliente respondeu" já rodou nesta permanência do
    # card na etapa (roda uma vez só por etapa; zera quando o card muda de etapa).
    add_column :pipeline_cards, :reply_triggered_at, :datetime
  end
end
