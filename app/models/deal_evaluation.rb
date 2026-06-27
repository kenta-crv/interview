class DealEvaluation < ApplicationRecord
  belongs_to :deal
  belongs_to :user

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :deal_id }
end
