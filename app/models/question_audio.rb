# app/models/question_audio.rb
class QuestionAudio < ApplicationRecord
  belongs_to :question
  has_one_attached :audio

  validates :language, presence: true
end
