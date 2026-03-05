class AddBranchingToQuestions < ActiveRecord::Migration[6.1]
  def change
    add_column :questions, :required, :boolean, default: true, null: false
    add_column :questions, :category, :string
    add_column :questions, :branching_rules, :json
  end
end
