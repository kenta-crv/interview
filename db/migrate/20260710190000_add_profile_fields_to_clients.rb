class AddProfileFieldsToClients < ActiveRecord::Migration[6.1]
  def change
    add_column :clients, :company, :string
    add_column :clients, :name, :string
    add_column :clients, :tel, :string
    add_column :clients, :address, :string
    add_column :clients, :url, :string
  end
end
