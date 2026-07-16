# app/models/user_progress.rb
class UserProgress < ApplicationRecord
  belongs_to :user
  belongs_to :deal
  has_many :deal_presentation_events, dependent: :destroy
  has_many :follow_up_deliveries, dependent: :destroy
  has_many :follow_up_unsubscribes, dependent: :destroy

  validates :user_id, :deal_id, presence: true
  validates :user_id, uniqueness: { scope: :deal_id }
  validates :prospect_grade, inclusion: { in: %w[A B C D] }, allow_nil: true

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

  def session_summary_hash
    raw = session_summary
    return {} if raw.blank?
    return raw if raw.is_a?(Hash)

    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def session_summary_lines
    summary = session_summary_hash
    [
      ("課題：#{summary['challenge']}" if summary['challenge'].present?),
      ("関心：#{summary['interest']}" if summary['interest'].present?),
      ("検討：#{summary['consideration']}" if summary['consideration'].present?),
      ("次アクション：#{summary['next_action']}" if summary['next_action'].present?)
    ].compact
  end

  def deal_evaluation
    deal.deal_evaluations.find_by(user_id: user_id)
  end
end
