# db/migrate/20260610132722_add_access_token_to_deals.rb
class AddAccessTokenToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :access_token, :string
    add_index :deals, :access_token, unique: true
  end
end
