# app/models/deal_summary.rb
class DealSummary < ApplicationRecord
  belongs_to :deal

  validates :deal_id, :summary, presence: true
end
