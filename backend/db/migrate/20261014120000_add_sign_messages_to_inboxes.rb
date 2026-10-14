class AddSignMessagesToInboxes < ActiveRecord::Migration[8.1]
  def change
    add_column :inboxes, :sign_messages, :boolean, default: false, null: false
  end
end
