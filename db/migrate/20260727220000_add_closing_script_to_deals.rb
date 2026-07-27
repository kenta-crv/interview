class AddClosingScriptToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :closing_script, :text
  end
end
