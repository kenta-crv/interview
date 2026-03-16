# Day 9: インデックス追加・FK制約追加・レガシーAnswerテーブル削除
class Day9SecurityAndDbImprovements < ActiveRecord::Migration[6.1]
  def up
    # === レガシー Answer テーブルの削除 ===
    # interview_responses テーブルで完全に置き換え済み
    drop_table :answers if table_exists?(:answers)

    # === インデックス追加 ===

    # interviews: ステータス+作成日での検索最適化（管理画面一覧等）
    add_index :interviews, [:status, :created_at],
              name: 'index_interviews_on_status_and_created_at'

    # interview_responses: 時系列での検索最適化
    add_index :interview_responses, :created_at,
              name: 'index_interview_responses_on_created_at'

    # questions: situation内の順序取得最適化（最頻出クエリ）
    add_index :questions, [:situation_id, :order],
              name: 'index_questions_on_situation_id_and_order'

    # situations: クライアント別アクティブ一覧の最適化
    add_index :situations, [:client_id, :archived],
              name: 'index_situations_on_client_id_and_archived'

    # === FK制約追加 ===

    # situations → clients（既存のスキーマで欠落していた制約）
    unless foreign_key_exists?(:situations, :clients)
      add_foreign_key :situations, :clients
    end
  end

  def down
    # FK制約の削除
    remove_foreign_key :situations, :clients if foreign_key_exists?(:situations, :clients)

    # インデックスの削除
    remove_index :situations, name: 'index_situations_on_client_id_and_archived', if_exists: true
    remove_index :questions, name: 'index_questions_on_situation_id_and_order', if_exists: true
    remove_index :interview_responses, name: 'index_interview_responses_on_created_at', if_exists: true
    remove_index :interviews, name: 'index_interviews_on_status_and_created_at', if_exists: true

    # Answer テーブルの復元
    create_table :answers do |t|
      t.integer :user_id, null: false
      t.integer :situation_id, null: false
      t.json :responses, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps precision: 6
      t.index :situation_id
      t.index :user_id
    end
    add_foreign_key :answers, :situations
  end
end
