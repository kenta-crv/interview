# db/migrate/20260612000000_create_deal_pages.rb
class CreateDealPages < ActiveRecord::Migration[6.1]
  def change
    create_table :deal_pages do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :deal_document, null: false, foreign_key: true
      t.integer :page_number, null: false
      t.text :script
      t.string :audio_url
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :deal_pages, [:deal_id, :page_number], unique: true
  end
end
