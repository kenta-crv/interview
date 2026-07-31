class MakeDealsClientIdOptional < ActiveRecord::Migration[6.1]
  def change
    change_column_null :deals, :client_id, true
  end
end
