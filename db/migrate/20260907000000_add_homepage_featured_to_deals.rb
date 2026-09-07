class AddHomepageFeaturedToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :homepage_featured, :boolean, null: false, default: false
    add_index :deals, :homepage_featured
  end
end
