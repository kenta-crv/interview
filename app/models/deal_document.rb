# app/models/deal_document.rb
class DealDocument < ApplicationRecord
  belongs_to :deal
  has_one_attached :file

  DOCUMENT_KINDS = %w[proposal supplement].freeze

  validates :deal_id, :filename, presence: true
  validates :document_kind, inclusion: { in: DOCUMENT_KINDS }

  scope :proposals, -> { where(document_kind: "proposal") }
  scope :supplements, -> { where(document_kind: "supplement") }

  def proposal?
    document_kind == "proposal"
  end

  def supplement?
    document_kind == "supplement"
  end

  def file_size_mb
    return nil unless file_size

    (file_size.to_f / 1024 / 1024).round(2)
  end
end
