class Situation < ApplicationRecord
  belongs_to :client
  has_many :questions, dependent: :destroy
  has_many :answers, dependent: :destroy
end
