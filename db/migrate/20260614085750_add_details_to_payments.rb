class AddDetailsToPayments < ActiveRecord::Migration[6.1]
  def change
    # CreatePayments で既に作られている列もあるため、未作成のものだけ追加する
    unless column_exists?(:payments, :client_id)
      add_reference :payments, :client, null: false, foreign_key: true
    end

    unless column_exists?(:payments, :campaign_id)
      # campaigns テーブルがまだ存在しないため foreign_key: false
      add_reference :payments, :campaign, null: true, foreign_key: false
    end

    add_column :payments, :amount, :integer, null: false, default: 0 unless column_exists?(:payments, :amount)
    add_column :payments, :status, :string unless column_exists?(:payments, :status)
    add_column :payments, :stripe_payment_intent_id, :string unless column_exists?(:payments, :stripe_payment_intent_id)
    add_column :payments, :description, :string unless column_exists?(:payments, :description)

    unless index_exists?(:payments, :stripe_payment_intent_id)
      add_index :payments, :stripe_payment_intent_id, unique: true
    end
  end
end
