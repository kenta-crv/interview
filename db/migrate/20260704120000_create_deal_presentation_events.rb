class CreateDealPresentationEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :deal_presentation_events do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :user_progress, foreign_key: true
      t.string :session_key, null: false
      t.string :event_type, null: false
      t.integer :page_number
      t.string :topic
      t.string :label
      t.text :message
      t.json :metadata, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :deal_presentation_events, [:deal_id, :occurred_at], name: 'idx_deal_pres_events_on_deal_and_time'
    add_index :deal_presentation_events, [:deal_id, :user_id, :occurred_at], name: 'idx_deal_pres_events_on_deal_user_time'
    add_index :deal_presentation_events, [:session_key, :occurred_at], name: 'idx_deal_pres_events_on_session_time'
    add_index :deal_presentation_events, :event_type, name: 'idx_deal_pres_events_on_event_type'
  end
end
