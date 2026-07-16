class AddPageViewsCountToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :page_views_count, :integer, null: false, default: 0
  end
end
