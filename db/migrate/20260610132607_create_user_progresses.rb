# db/migrate/20260610132607_create_user_progresses.rb
class CreateUserProgresses < ActiveRecord::Migration[6.1]
  def change
    create_table :user_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :deal, null: false, foreign_key: true
      
      # 検討フェーズ
      t.string :consideration_phase
      # 導入予定
      t.date :planned_introduction_date
      # 申し込みを行う重要ポイント
      t.text :key_points_for_application
      
      t.timestamps
    end

    add_index :user_progresses, [:user_id, :deal_id], unique: true
  end
end
