# app/models/user_progress.rb
class UserProgress < ApplicationRecord
  belongs_to :user
  belongs_to :deal
  has_many :deal_presentation_events, dependent: :destroy

  validates :user_id, :deal_id, presence: true
  validates :user_id, uniqueness: { scope: :deal_id }

  enum consideration_phase: {
    initial: 0,
    information_gathering: 1,
    evaluation: 2,
    decision: 3
  }
end
