class FollowUpDelivery < ApplicationRecord
  belongs_to :user_progress
  belongs_to :deal_follow_up_template

  STATUSES = %w[scheduled sent opened cancelled failed].freeze

  validates :sequence, :subject, :body, :scheduled_at, :tracking_token, :sales_click_token, :contract_click_token, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :sequence, uniqueness: { scope: :user_progress_id }
  validates :tracking_token, :sales_click_token, :contract_click_token, uniqueness: true

  scope :pending_send, -> { where(status: "scheduled").where("scheduled_at <= ?", Time.current) }
  scope :ordered, -> { order(:sequence) }
  scope :recent_first, -> { order(sent_at: :desc, scheduled_at: :desc) }

  before_validation :assign_tokens, on: :create

  def deal
    user_progress.deal
  end

  def user
    user_progress.user
  end

  def mark_sent!
    update!(status: "sent", sent_at: Time.current)
  end

  def mark_opened!
    return if opened_at.present?

    update!(opened_at: Time.current, status: "opened")
  end

  def mark_sales_call_clicked!
    return if sales_call_clicked_at.present?

    update!(sales_call_clicked_at: Time.current)
  end

  def mark_contract_clicked!
    return if contract_clicked_at.present?

    update!(contract_clicked_at: Time.current)
  end

  def cancel!
    update!(status: "cancelled") if status == "scheduled"
  end

  def sent_or_beyond?
    %w[sent opened].include?(status)
  end

  private

  def assign_tokens
    self.tracking_token ||= SecureRandom.urlsafe_base64(24)
    self.sales_click_token ||= SecureRandom.urlsafe_base64(24)
    self.contract_click_token ||= SecureRandom.urlsafe_base64(24)
  end
end
