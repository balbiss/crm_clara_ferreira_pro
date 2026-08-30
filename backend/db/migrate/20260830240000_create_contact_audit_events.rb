class CreateContactAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # Trilha de auditoria de Contact (briefing seção 22 "histórico de
    # transferência de responsável" + pendência "histórico de mudança de
    # status" levantada na auditoria do briefing original). changed_by nulo =
    # mudança feita pelo sistema (sync do Jueri, régua automática), não por
    # uma pessoa pela tela.
    create_table :contact_audit_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :changed_by, foreign_key: { to_table: :users }, null: true

      t.string :event_type, null: false # responsavel | status
      t.string :from_value
      t.string :to_value

      t.timestamps
    end

    add_index :contact_audit_events, [:contact_id, :event_type, :created_at], name: "idx_contact_audit_events_contact_type_time"
    add_index :contact_audit_events, [:account_id, :event_type]
  end
end
