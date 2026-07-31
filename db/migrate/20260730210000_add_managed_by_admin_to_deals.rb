class AddManagedByAdminToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :managed_by_admin, :boolean, null: false, default: false
    add_index :deals, :managed_by_admin
  end
end
