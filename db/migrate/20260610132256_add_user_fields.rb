# db/migrate/20260610132256_add_user_fields.rb
class AddUserFields < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :company, :string
    add_column :users, :tel, :string
    add_column :users, :address, :text
    add_column :users, :url, :string

    add_index :users, :company
  end
end
