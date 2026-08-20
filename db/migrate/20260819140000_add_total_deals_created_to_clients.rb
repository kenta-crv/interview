class AddTotalDealsCreatedToClients < ActiveRecord::Migration[6.1]
  def up
    add_column :clients, :total_deals_created, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE clients SET total_deals_created = (
        SELECT COUNT(*) FROM deals WHERE deals.client_id = clients.id
      )
    SQL
  end

  def down
    remove_column :clients, :total_deals_created
  end
end
