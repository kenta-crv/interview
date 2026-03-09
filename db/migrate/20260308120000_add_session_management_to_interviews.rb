class AddSessionManagementToInterviews < ActiveRecord::Migration[6.1]
  def change
    # URL即時開始用トークン
    add_column :interviews, :access_token, :string
    add_index :interviews, :access_token, unique: true

    # セッション管理用
    add_column :interviews, :last_activity_at, :datetime
    add_column :interviews, :resumed_at, :datetime
    add_column :interviews, :resume_count, :integer, default: 0, null: false

    # Situation にタイムアウト設定を追加（Client設定ベース）
    add_column :situations, :session_timeout_minutes, :integer, default: 60, null: false
    add_column :situations, :allow_resume, :boolean, default: true, null: false
    add_column :situations, :max_resume_count, :integer, default: 3, null: false
  end
end
