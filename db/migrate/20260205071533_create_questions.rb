class CreateQuestions < ActiveRecord::Migration[6.1]
  def change
    create_table :questions do |t|
      t.references :situation, null: false, foreign_key: true
      t.text :question_text, null: false
      t.string :question_type, null: false
      t.json :options
      t.integer :order

      t.timestamps
    end
  end
end
