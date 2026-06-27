class EnhanceDealPlaybackSystem < ActiveRecord::Migration[6.1]
  def change
    change_table :deals, bulk: true do |t|
      t.text :greeting_script
      t.text :company_overview_script
      t.text :usage_guide_script
      t.json :menu_items, default: []
      t.boolean :playback_ready, default: false, null: false
    end

    change_table :deal_pages, bulk: true do |t|
      t.string :title
      t.text :page_text
    end

    create_table :deal_evaluations do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :feedback
      t.timestamps
    end

    add_index :deal_evaluations, [:deal_id, :user_id], unique: true
  end
end
