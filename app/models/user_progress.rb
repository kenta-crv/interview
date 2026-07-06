# app/models/user_progress.rb
class UserProgress < ApplicationRecord
  belongs_to :user
  belongs_to :deal
  has_many :deal_presentation_events, dependent: :destroy
  has_many :follow_up_deliveries, dependent: :destroy
  has_many :follow_up_unsubscribes, dependent: :destroy

  validates :user_id, :deal_id, presence: true
  validates :user_id, uniqueness: { scope: :deal_id }

  enum consideration_phase: {
    initial: 0,
    information_gathering: 1,
    evaluation: 2,
    decision: 3
  }

  def follow_up_unsubscribed?
    follow_up_unsubscribed_at.present?
  end

  def ensure_follow_up_unsubscribe_token!
    return follow_up_unsubscribe_token if follow_up_unsubscribe_token.present?

    update!(follow_up_unsubscribe_token: SecureRandom.urlsafe_base64(24))
    follow_up_unsubscribe_token
  end
end
