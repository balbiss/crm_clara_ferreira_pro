class AddResultadoToTarefas < ActiveRecord::Migration[8.0]
  def change
    # Reforma do fluxo de tarefas (PDF Etapa 2, página 9): ao concluir, o
    # consultor registra o que aconteceu (ligou e não atendeu, fechou pedido,
    # remarcou etc). Antes "concluir" era só um botão sem nenhum registro.
    add_column :tarefas, :resultado, :text
  end
end
