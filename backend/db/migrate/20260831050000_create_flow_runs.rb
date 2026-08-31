class CreateFlowRuns < ActiveRecord::Migration[8.1]
  def change
    # Estado de uma execução de Fluxo em andamento numa conversa — existe
    # pra suportar nós que precisam PARAR e esperar a próxima mensagem do
    # contato (Perguntar, Botões/Lista): `current_node_key` marca onde
    # parou, `variables` guarda o que já foi capturado (usado tanto na
    # interpolação de mensagens quanto na Condição de verdade).
    create_table :flow_runs do |t|
      t.references :flow, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :current_node_key
      t.jsonb :variables, null: false, default: {}
      t.string :status, null: false, default: 'running' # running | waiting_reply | completed

      t.timestamps
    end

    add_index :flow_runs, [:conversation_id, :status]
  end
end
