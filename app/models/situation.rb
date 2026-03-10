class Situation < ApplicationRecord
  belongs_to :client
  has_many :questions, dependent: :destroy
  has_many :answers, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews

  validates :title, presence: true
  validates :session_timeout_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 180 }
  validates :max_resume_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :passing_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :min_required_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :max_consecutive_fails, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :reject_notify_method, inclusion: { in: %w[in_app email none] }

  enum language: { en: 'en', ja: 'ja' }

  scope :active, -> { where(archived: false) }

  def allow_resume?
    allow_resume
  end

  def auto_reject_enabled?
    auto_reject_enabled
  end

  def reject_on_required_fail?
    reject_on_required_fail
  end
end
