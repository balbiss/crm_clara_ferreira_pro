class CreateLifecycleEvents < ActiveRecord::Migration[8.1]
  def change
    # Marcos históricos do ciclo de vida (distintos do status atual, que já vive
    # em contacts.status/status_changed_at e é sobrescrito a cada transição).
    # Iniciada/Churn/Reativação são EVENTOS — precisam ficar em uma tabela à
    # parte pra dar pra reconstruir "quantas vezes ela deu Churn", "quando foi
    # a 1a vez que ela ativou", etc.
    create_table :lifecycle_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      # Pedido que disparou o evento (ex: qual pedido fez ela cruzar o limiar
      # de 25 peças) — opcional porque nem todo evento tem um pedido único
      # associado (ex: reativação pode ser resultado de vários pedidos juntos).
      t.references :pedido, null: true, foreign_key: true

      t.string :event_type, null: false # iniciada | churn | reativacao
      t.datetime :occurred_at, null: false

      # Contexto do momento do evento (peças abertas antes/depois, etc.) —
      # jsonb pra não precisar de migration nova a cada novo dado de contexto.
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :lifecycle_events, [:contact_id, :event_type, :occurred_at], name: "idx_lifecycle_events_contact_type_time"
    add_index :lifecycle_events, [:account_id, :event_type]

    # Regra inviolável do ciclo de vida: "Iniciada" só pode acontecer 1x na
    # vida da revendedora. Garantido no banco, não só na aplicação.
    add_index :lifecycle_events, :contact_id, unique: true,
      where: "event_type = 'iniciada'", name: "idx_lifecycle_events_iniciada_unica"
  end
end
