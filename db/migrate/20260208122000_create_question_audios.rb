# frozen_string_literal: true

class CreateQuestionAudios < ActiveRecord::Migration[6.1]
  def change
    create_table :question_audios do |t|
      t.references :question, null: false, foreign_key: true
      t.string :language, null: false, default: 'en'
      t.timestamps
    end

    add_index :question_audios, [:question_id, :language], unique: true
  end
end
