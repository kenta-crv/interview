class Question < ApplicationRecord
  belongs_to :situation
  validates :question_text, :question_type, presence: true
end