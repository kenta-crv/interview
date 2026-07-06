class FollowUpUnsubscribe < ApplicationRecord
  belongs_to :user_progress

  validates :token, :unsubscribed_at, presence: true
  validates :token, uniqueness: true

  before_validation :assign_token, on: :create

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(24)
    self.unsubscribed_at ||= Time.current
  end
end
