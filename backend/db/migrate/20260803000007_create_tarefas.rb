class CreateTarefas < ActiveRecord::Migration[8.1]
  def change
    # Motor de tarefas da régua — antes as "tarefas" eram só derivadas em
    # tempo real no frontend (status + dias no ciclo), sem persistência.
    # Isso impedia auditoria de verdade (não dava pra saber quem concluiu,
    # quando, nem ter uma tarefa "vencida" de fato — era tudo recalculado a
    # cada carregamento de tela). Agora existe uma tarefa de verdade por
    # marco do ciclo (3º/10º/20º dia, atrasada), criada automaticamente pelo
    # ReguaAutoAdvanceJob na hora exata da transição.
    create_table :tarefas do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true # responsável (denormalizado do contact, pode mudar depois)

      t.string :tipo, null: false # terceiro_dia | decimo_dia | vigesimo_dia | atrasada
      t.string :titulo, null: false
      t.text :descricao
      t.string :prioridade, null: false, default: 'normal' # normal | alta | urgente
      t.string :status, null: false, default: 'pendente' # pendente | concluida | ignorada

      t.datetime :vencimento_em
      t.datetime :concluida_em
      t.references :concluida_por, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :tarefas, [:account_id, :status]
    add_index :tarefas, [:user_id, :status]
    # No máximo 1 tarefa PENDENTE do mesmo tipo por revendedora — o job de
    # régua roda de hora em hora, sem isso duplicaria a cada execução.
    add_index :tarefas, [:contact_id, :tipo], unique: true, where: "status = 'pendente'",
      name: "idx_tarefas_pendente_unica_por_tipo"
  end
end
