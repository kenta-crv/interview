class AddIndustryToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :industry, :string, null: false, default: "general"
    add_index :deals, :industry
  end
end
