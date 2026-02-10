# app/models/interview.rb
class Interview < ApplicationRecord
  belongs_to :user
  belongs_to :situation
  has_many :interview_responses, dependent: :destroy
  has_one :interview_result, dependent: :destroy

  enum status: {
    not_started: 0,
    in_progress: 1,
    completed: 2,
    failed: 3,
    abandoned: 4
  }

  enum language: {
    en: 'en',
    ja: 'ja'
  }

  validates :user_id, :situation_id, :language, presence: true
  validates :user_id, uniqueness: { scope: :situation_id, message: "can only interview once per situation" }

  # Business Rules
  validate :ensure_no_previous_interview, on: :create
  validate :ensure_situation_has_questions, on: :create

  scope :by_user_and_situation, ->(user, situation) { where(user: user, situation: situation) }
  scope :completed_or_failed, -> { where(status: [:completed, :failed]) }

  def start!
    update!(status: :in_progress, started_at: Time.current)
  end

  def complete!
    update!(status: :completed, ended_at: Time.current)
  end

  def fail!
    update!(status: :failed, ended_at: Time.current)
  end

  def duration
    return nil unless started_at && ended_at
    (ended_at - started_at).to_i
  end

  def answered_question_count
    interview_responses.count
  end

  def total_questions
    situation.questions.count
  end

  def progress_percentage
    return 0 if total_questions.zero?
    ((answered_question_count.to_f / total_questions) * 100).round(2)
  end

  private

  def ensure_no_previous_interview
    existing = Interview.by_user_and_situation(user, situation).completed_or_failed.exists?
    errors.add(:base, "User has already completed this interview") if existing
  end

  def ensure_situation_has_questions
    errors.add(:situation, "must have at least 1 question") if situation.questions.empty?
  end
end
