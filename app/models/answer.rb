class Answer < ApplicationRecord
  belongs_to :situation
  belongs_to :user
  # responsesはJSONで質問IDと回答を紐付け
end