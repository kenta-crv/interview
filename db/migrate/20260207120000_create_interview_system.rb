# db/migrate/[timestamp]_create_interview_system.rb
class CreateInterviewSystem < ActiveRecord::Migration[6.1]
  def change
    create_table :interviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :situation, null: false, foreign_key: true
      t.integer :status, default: 0  # not_started, in_progress, completed, failed, abandoned
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end

    add_index :interviews, [:user_id, :situation_id], unique: true, name: 'index_interviews_on_user_and_situation'

    create_table :interview_responses do |t|
      t.references :interview, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.text :audio_transcript, null: false
      t.integer :evaluation_status, default: 0  # pending, evaluating, completed, failed
      t.json :evaluation_data, default: {}

      t.timestamps
    end

    add_index :interview_responses, [:interview_id, :question_id], unique: true, name: 'index_responses_on_interview_and_question'
    add_index :interview_responses, :evaluation_status

    create_table :interview_results do |t|
      t.references :interview, null: false, foreign_key: true
      t.integer :final_status  # passed, failed, incomplete
      t.json :results_data, default: {}

      t.timestamps
    end

    add_index :interview_results, :final_status
    add_index :interview_results, [:interview_id], unique: true, name: 'index_interview_results_on_interview_id_unique'
  end
end
