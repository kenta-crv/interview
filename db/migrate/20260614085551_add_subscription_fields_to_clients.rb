class AddSubscriptionFieldsToClients < ActiveRecord::Migration[6.1]
  def change
    add_column :clients, :subscription_plan, :string
    add_column :clients, :subscription_status, :string
  end
end
