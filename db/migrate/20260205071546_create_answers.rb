class CreateAnswers < ActiveRecord::Migration[6.1]
  def change
    create_table :answers do |t|
      t.integer :user_id, null: false
      t.references :situation, null: false, foreign_key: true
      t.json :responses, null: false
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :answers, :user_id
  end
end
