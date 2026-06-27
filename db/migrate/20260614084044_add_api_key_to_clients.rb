class AddApiKeyToClients < ActiveRecord::Migration[6.1]
  def change
    add_column :clients, :api_key, :string
  end
end
