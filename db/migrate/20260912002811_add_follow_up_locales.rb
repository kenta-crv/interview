class AddFollowUpLocales < ActiveRecord::Migration[6.1]
  def change
    add_column :user_progresses, :locale, :string, null: false, default: "ja"
    add_column :deal_follow_up_templates, :subject_en, :string
    add_column :deal_follow_up_templates, :body_en, :text
  end
end
