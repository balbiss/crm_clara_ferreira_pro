class AddDelayAndFlowActionToTriggers < ActiveRecord::Migration[8.0]
  def change
    # Condição de tempo pro gatilho (PDF Etapa 2, página 11 — exemplo do
    # Kommo: "Realiza a ação X horas após o lead entrar nessa etapa").
    # 0 = imediato (comportamento de sempre, sem mudança pra quem já usa).
    add_column :pipeline_triggers, :delay_minutes, :integer, default: 0, null: false
    add_column :regua_triggers, :delay_minutes, :integer, default: 0, null: false
  end
end
