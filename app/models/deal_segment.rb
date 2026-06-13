# app/models/deal_segment.rb
class DealSegment < ApplicationRecord
  belongs_to :deal_audio
  has_one_attached :audio_file

  enum transcription_status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  validates :deal_audio_id, :segment_number, presence: true

  scope :in_order, -> { order(:segment_number) }
  scope :pending_transcription, -> { where(transcription_status: :pending) }
  scope :completed_transcription, -> { where(transcription_status: :completed) }

  def duration_minutes
    return nil unless duration_seconds
    (duration_seconds.to_f / 60).round(2)
  end
end
