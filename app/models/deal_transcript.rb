# app/models/deal_transcript.rb
class DealTranscript < ApplicationRecord
  belongs_to :deal

  validates :deal_id, :full_transcript, presence: true

  def total_duration_minutes
    return nil unless total_duration_seconds
    (total_duration_seconds.to_f / 60).round(2)
  end
end
