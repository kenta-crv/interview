# db/migrate/20260604225705_create_deal_system.rb
class CreateDealSystem < ActiveRecord::Migration[6.1]
  def change
    create_table :deals do |t|
      t.references :client, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :status, default: 0  # uploading, processing, transcribing, summarizing, completed, failed
      t.datetime :deal_date
      t.string :language, default: 'ja'
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :deals, :status
    add_index :deals, [:client_id, :status]

    create_table :deal_documents do |t|
      t.references :deal, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :content_type
      t.bigint :file_size
      t.json :metadata, default: {}

      t.timestamps
    end

    create_table :deal_audios do |t|
      t.references :deal, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :content_type
      t.bigint :file_size
      t.integer :duration_seconds
      t.integer :segment_count, default: 0
      t.json :metadata, default: {}

      t.timestamps
    end

    create_table :deal_segments do |t|
      t.references :deal_audio, null: false, foreign_key: true, index: false
      t.integer :segment_number, null: false
      t.float :start_time
      t.float :end_time
      t.integer :duration_seconds
      t.string :audio_file_path
      t.integer :transcription_status, default: 0  # pending, processing, completed, failed
      t.text :transcript

      t.timestamps
    end

    add_index :deal_segments, [:deal_audio_id, :segment_number], unique: true, name: 'index_deal_segments_on_audio_and_number'
    add_index :deal_segments, :deal_audio_id
    add_index :deal_segments, :transcription_status

    create_table :deal_transcripts do |t|
      t.references :deal, null: false, foreign_key: true
      t.text :full_transcript, null: false
      t.integer :segment_count
      t.float :total_duration_seconds
      t.json :metadata, default: {}

      t.timestamps
    end

    create_table :deal_summaries do |t|
      t.references :deal, null: false, foreign_key: true
      t.text :summary, null: false
      t.text :key_points
      t.text :action_items
      t.text :participants
      t.text :next_steps
      t.json :metadata, default: {}

      t.timestamps
    end
  end
end
