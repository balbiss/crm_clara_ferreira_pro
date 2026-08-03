class AddReguaTrackingToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :status_changed_at, :datetime
    add_column :contacts, :cycle_started_at, :datetime
    add_index :contacts, :status_changed_at
  end
end
