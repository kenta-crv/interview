class Situation < ApplicationRecord
  belongs_to :client
  has_many :questions, dependent: :destroy
  has_many :answers, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews

  validates :title, presence: true
  validates :session_timeout_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 180 }
  validates :max_resume_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }

  enum language: { en: 'en', ja: 'ja' }

  scope :active, -> { where(archived: false) }

  def allow_resume?
    allow_resume
  end
end
