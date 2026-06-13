# app/models/deal_page.rb
class DealPage < ApplicationRecord
  belongs_to :deal
  belongs_to :deal_document
  has_one_attached :page_audio

  validates :deal_id, :deal_document_id, :page_number, presence: true
  validates :page_number, uniqueness: { scope: :deal_id }
end
