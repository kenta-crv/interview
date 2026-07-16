class AddSessionAnalysisToUserProgresses < ActiveRecord::Migration[6.1]
  def change
    add_column :user_progresses, :prospect_grade, :string
    add_column :user_progresses, :prospect_score, :integer
    add_column :user_progresses, :session_summary, :json, default: {}
    add_column :user_progresses, :session_analyzed_at, :datetime
  end
end
