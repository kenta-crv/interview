class CreateDealFaqs < ActiveRecord::Migration[6.1]
  def change
    create_table :deal_faqs do |t|
      t.references :deal, null: false, foreign_key: true
      t.text :question, null: false
      t.text :answer
      t.string :category, null: false, default: "other"
      t.string :source, null: false, default: "manual"
      t.string :status, null: false, default: "approved"
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :deal_faqs, [:deal_id, :status]
    add_index :deal_faqs, [:deal_id, :position]
  end
end
