class AddDataAcertoToPedidos < ActiveRecord::Migration[8.0]
  def change
    add_column :pedidos, :data_acerto, :date
  end
end
