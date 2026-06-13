class CreateDealPresentations < ActiveRecord::Migration[6.1]
  def change
    create_table :deal_presentations do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :situation, null: false, foreign_key: true
      t.integer :status, default: 0
      t.text :current_step
      t.json :user_choices, default: []
      t.json :guidance_history, default: []

      t.timestamps
    end
  end
end
