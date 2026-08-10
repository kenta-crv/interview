class DealFollowUpTemplate < ApplicationRecord
  belongs_to :deal
  has_many :follow_up_deliveries, dependent: :restrict_with_exception

  SEQUENCES = (1..5).freeze
  MAX_SEQUENCE = 5

  validates :sequence, presence: true, inclusion: { in: SEQUENCES }
  validates :sequence, uniqueness: { scope: :deal_id }
  validates :subject, :body, presence: true
  validates :delay_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 365 }

  scope :ordered, -> { order(:sequence) }
  scope :enabled, -> { where(enabled: true) }

  def initial?
    sequence == 1
  end

  def label
    if sequence == 1
      I18n.t("meetia.dashboard.follow_up.initial")
    else
      I18n.t("meetia.dashboard.follow_up.nurture", n: sequence - 1)
    end
  end
end
