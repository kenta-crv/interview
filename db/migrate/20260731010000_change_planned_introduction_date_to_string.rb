class ChangePlannedIntroductionDateToString < ActiveRecord::Migration[6.1]
  def up
    change_column :user_progresses, :planned_introduction_date, :string
  end

  def down
    change_column :user_progresses, :planned_introduction_date, :date
  end
end
