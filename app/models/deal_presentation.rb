class DealPresentation < ApplicationRecord
  belongs_to :deal
  belongs_to :situation

  enum status: {
    not_started: 0,
    in_progress: 1,
    completed: 2,
    paused: 3
  }

  validates :deal_id, :situation_id, presence: true

  def add_user_choice(choice)
    self.user_choices ||= []
    self.user_choices << { choice: choice, timestamp: Time.current }
    save!
  end

  def add_guidance(guidance)
    self.guidance_history ||= []
    self.guidance_history << { guidance: guidance, timestamp: Time.current }
    save!
  end

  def latest_guidance
    guidance_history&.last&.dig(:guidance)
  end
end
