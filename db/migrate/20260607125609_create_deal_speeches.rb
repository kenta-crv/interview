class CreateDealSpeeches < ActiveRecord::Migration[6.1]
  def change
    create_table :deal_speeches do |t|
      t.references :deal, null: false, foreign_key: true
      t.string :filename
      t.string :content_type
      t.bigint :file_size
      t.string :voice
      t.string :language
      t.json :metadata, default: {}

      t.timestamps
    end
  end
end
