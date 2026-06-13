class AddDealToSituations < ActiveRecord::Migration[6.1]
  def change
    add_reference :situations, :deal, null: true, foreign_key: true
    add_column :situations, :situation_type, :string
  end
end
