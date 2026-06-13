# app/models/deal_audio.rb
class DealAudio < ApplicationRecord
  belongs_to :deal
  has_many :deal_segments, dependent: :destroy
  has_one_attached :audio_file

  validates :deal_id, :filename, presence: true

  def file_size_mb
    return nil unless file_size
    (file_size.to_f / 1024 / 1024).round(2)
  end

  def duration_minutes
    return nil unless duration_seconds
    (duration_seconds.to_f / 60).round(2)
  end
end
