class AddRestrictByPortfolioToInboxes < ActiveRecord::Migration[8.1]
  def change
    add_column :inboxes, :restrict_by_portfolio, :boolean, default: false, null: false
  end
end
