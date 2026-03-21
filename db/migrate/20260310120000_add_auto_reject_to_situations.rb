class AddAutoRejectToSituations < ActiveRecord::Migration[6.1]
  def change
    # Situation: リジェクト設定（Client が Situation 単位で設定）
    add_column :situations, :passing_score, :integer, default: 70, null: false
    add_column :situations, :auto_reject_enabled, :boolean, default: true, null: false
    add_column :situations, :reject_on_required_fail, :boolean, default: true, null: false
    add_column :situations, :min_required_score, :integer, default: 70, null: false
    add_column :situations, :max_consecutive_fails, :integer, default: 0, null: false
    add_column :situations, :reject_notify_method, :string, default: 'in_app', null: false

    # Interview: リジェクト記録
    add_column :interviews, :rejection_reason, :string
    add_column :interviews, :rejected_at, :datetime

    # InterviewResult: リジェクト詳細
    add_column :interview_results, :rejection_details, :json, default: {}
  end
end
