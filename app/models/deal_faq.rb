class DealFaq < ApplicationRecord
  belongs_to :deal

  CATEGORIES = {
    "pricing" => "料金・契約",
    "implementation" => "導入・体制",
    "security" => "セキュリティ",
    "comparison" => "競合・比較",
    "support" => "サポート",
    "contract" => "契約条件",
    "other" => "その他"
  }.freeze

  SOURCES = %w[manual ai_gap template supplement_pdf session_log stress_test checklist].freeze

  SOURCE_LABELS = {
    "manual" => "手動",
    "ai_gap" => "AI提案",
    "template" => "テンプレート",
    "supplement_pdf" => "補足PDF",
    "session_log" => "商談ログ",
    "stress_test" => "ストレステスト",
    "checklist" => "チェックリスト"
  }.freeze
  STATUSES = %w[pending approved skipped].freeze

  validates :question, presence: true
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }

  scope :ordered, -> { order(:position, :id) }
  scope :approved, -> { where(status: "approved") }
  scope :pending, -> { where(status: "pending") }
  scope :actionable, -> { where(status: %w[pending approved]) }
  scope :for_conversation, -> { approved.where.not(answer: [nil, ""]) }

  def category_label
    CATEGORIES[category] || category
  end

  def answered?
    answer.present?
  end

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def skipped?
    status == "skipped"
  end

  def ai_gap?
    source == "ai_gap"
  end

  def source_label
    SOURCE_LABELS[source] || source
  end

  def approve!(answer_text)
    update!(answer: answer_text, status: "approved")
  end

  def skip!
    update!(status: "skipped")
  end
end
