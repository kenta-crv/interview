class CreateSituations < ActiveRecord::Migration[6.1]
  def change
    create_table :situations do |t|
      t.string :title, null: false
      t.text :description
      t.integer :client_id, null: false

      t.timestamps
    end

    add_index :situations, :client_id
  end
end
