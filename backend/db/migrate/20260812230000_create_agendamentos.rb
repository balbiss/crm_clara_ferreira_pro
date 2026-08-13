class CreateAgendamentos < ActiveRecord::Migration[8.1]
  def change
    create_table :agendamentos do |t|
      t.references :account, null: false, foreign_key: true
      # Dono/responsável do compromisso — quem criou (consultor) ou pra quem
      # foi atribuído (gerente/diretoria agendando em nome de alguém).
      t.references :user, null: false, foreign_key: true
      t.string :titulo, null: false
      t.text :descricao
      t.datetime :inicio_em, null: false
      t.datetime :fim_em

      t.timestamps
    end

    add_index :agendamentos, [:account_id, :inicio_em]
    add_index :agendamentos, [:user_id, :inicio_em]
  end
end
