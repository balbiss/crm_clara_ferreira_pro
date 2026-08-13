class AddBusinessFieldsToAgendamentos < ActiveRecord::Migration[8.1]
  def change
    add_reference :agendamentos, :contact, null: true, foreign_key: true
    add_column :agendamentos, :valor, :decimal, precision: 12, scale: 2
    add_column :agendamentos, :tipo, :string, null: false, default: 'outro'
  end
end
