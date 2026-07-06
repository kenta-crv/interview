class CreateDealFollowUpSystem < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :follow_up_sales_url, :string
    add_column :user_progresses, :session_ended_at, :datetime
    add_column :user_progresses, :follow_up_unsubscribe_token, :string
    add_column :user_progresses, :follow_up_unsubscribed_at, :datetime
    add_index :user_progresses, :follow_up_unsubscribe_token, unique: true

    create_table :deal_follow_up_templates do |t|
      t.references :deal, null: false, foreign_key: true
      t.integer :sequence, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :delay_days, null: false, default: 0
      t.string :subject, null: false
      t.text :body, null: false
      t.boolean :include_sales_call_link, null: false, default: true
      t.boolean :include_contract_link, null: false, default: true
      t.timestamps
    end
    add_index :deal_follow_up_templates, [:deal_id, :sequence], unique: true

    create_table :follow_up_deliveries do |t|
      t.references :user_progress, null: false, foreign_key: true
      t.references :deal_follow_up_template, null: false, foreign_key: true
      t.integer :sequence, null: false
      t.string :status, null: false, default: "scheduled"
      t.string :subject, null: false
      t.text :body, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :sales_call_clicked_at
      t.datetime :contract_clicked_at
      t.string :tracking_token, null: false
      t.string :sales_click_token, null: false
      t.string :contract_click_token, null: false
      t.text :error_message
      t.timestamps
    end
    add_index :follow_up_deliveries, :tracking_token, unique: true
    add_index :follow_up_deliveries, :sales_click_token, unique: true
    add_index :follow_up_deliveries, :contract_click_token, unique: true
    add_index :follow_up_deliveries, [:user_progress_id, :sequence], unique: true
    add_index :follow_up_deliveries, :status
    add_index :follow_up_deliveries, :scheduled_at

    create_table :follow_up_unsubscribes do |t|
      t.references :user_progress, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :unsubscribed_at, null: false
      t.string :source, null: false, default: "email_link"
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    add_index :follow_up_unsubscribes, :token, unique: true
  end
end
