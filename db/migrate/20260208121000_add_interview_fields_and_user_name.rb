# frozen_string_literal: true

class AddInterviewFieldsAndUserName < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :name, :string

    add_column :interviews, :language, :string, default: 'en', null: false

    add_column :situations, :language, :string, default: 'en', null: false
    add_column :situations, :archived, :boolean, default: false, null: false
  end
end
