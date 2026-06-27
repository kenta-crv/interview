class AddDetailsToPayments < ActiveRecord::Migration[6.1]
def change
    add_reference :payments, :client, null: false, foreign_key: true
    
    # campaignsテーブルがまだ存在しないため、foreign_key: true を削除します
    add_reference :payments, :campaign, null: true, foreign_key: false
    
    add_column :payments, :amount, :integer, null: false, default: 0
    add_column :payments, :status, :string
    add_column :payments, :stripe_payment_intent_id, :string
    add_column :payments, :description, :string

    add_index :payments, :stripe_payment_intent_id, unique: true
  end
end
