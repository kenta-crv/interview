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

  # ActiveStorage の attachment レコードがあっても、Disk 実体が消えていると download で落ちる
  def file_readable?
    return false unless file.attached?

    file.blob.service.exist?(file.blob.key)
  rescue StandardError
    false
  end

  # 実ファイル欠損時は通常の destroy! が purge で落ちるため、メタデータだけ消す
  def destroy_safely!
    if file_readable?
      destroy!
      return
    end

    ActiveRecord::Base.transaction do
      DealPage.where(deal_document_id: id).delete_all
      if file.attached?
        blob = file.blob
        file.attachment.delete
        blob.delete
      end
      delete
    end
  end
end
