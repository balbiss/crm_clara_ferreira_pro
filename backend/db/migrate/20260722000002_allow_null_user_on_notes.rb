# Notas criadas automaticamente por gatilho de pipeline (PipelineTriggerRunnerService)
# não têm um usuário humano como autor — precisa poder ficar nulo.
class AllowNullUserOnNotes < ActiveRecord::Migration[8.1]
  def change
    change_column_null :notes, :user_id, true
  end
end
