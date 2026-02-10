class Situation < ApplicationRecord
  belongs_to :client
  has_many :questions, dependent: :destroy
  has_many :answers, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews

  validates :title, presence: true
  
  enum language: { en: 'en', ja: 'ja' }
  
  scope :active, -> { where(archived: false) }
end
