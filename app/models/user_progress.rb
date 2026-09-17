# app/models/user_progress.rb
class UserProgress < ApplicationRecord
  belongs_to :user
  belongs_to :deal
  has_many :deal_presentation_events, dependent: :destroy
  has_many :follow_up_deliveries, dependent: :destroy
  has_many :follow_up_unsubscribes, dependent: :destroy

  LOCALES = %w[ja en].freeze
  JOURNEY_STEPS = %w[registered started viewed engaged converted completed].freeze
  JOURNEY_STEP_INDEX = JOURNEY_STEPS.each_with_index.to_h.freeze
  JOURNEY_EVENT_STEPS = {
    "presentation_start" => "started",
    "page_view" => "viewed",
    "topic_click" => "viewed",
    "free_text_send" => "engaged",
    "ai_reply" => "engaged",
    "chat_toggle" => "engaged",
    "cta_click" => "converted",
    "exit_contract_click" => "converted",
    "exit_sales_call_click" => "converted",
    "closing_play" => "converted",
    "last_button_click" => "converted",
    "materials_download" => "converted",
    "evaluation_submit" => "completed",
    "session_close" => "completed"
  }.freeze

  validates :user_id, :deal_id, presence: true
  validates :user_id, uniqueness: { scope: :deal_id }
  validates :prospect_grade, inclusion: { in: %w[A B C D] }, allow_nil: true
  validates :locale, inclusion: { in: LOCALES }

  def follow_up_locale
    LOCALES.include?(locale.to_s) ? locale.to_s : "ja"
  end

  enum consideration_phase: {
    initial: 0,
    information_gathering: 1,
    evaluation: 2,
    decision: 3
  }

  def follow_up_unsubscribed?
    follow_up_unsubscribed_at.present?
  end

  def ensure_follow_up_unsubscribe_token!
    return follow_up_unsubscribe_token if follow_up_unsubscribe_token.present?

    update!(follow_up_unsubscribe_token: SecureRandom.urlsafe_base64(24))
    follow_up_unsubscribe_token
  end

  def session_summary_hash
    raw = session_summary
    return {} if raw.blank?
    return raw if raw.is_a?(Hash)

    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def session_summary_lines
    summary = session_summary_hash
    [
      (I18n.t("meetia.owner_mail.challenge", text: summary["challenge"]) if summary["challenge"].present?),
      (I18n.t("meetia.owner_mail.interest", text: summary["interest"]) if summary["interest"].present?),
      (I18n.t("meetia.owner_mail.consideration", text: summary["consideration"]) if summary["consideration"].present?),
      (I18n.t("meetia.owner_mail.next_action", text: summary["next_action"]) if summary["next_action"].present?)
    ].compact
  end

  def deal_evaluation
    deal.deal_evaluations.find_by(user_id: user_id)
  end

  def self.journey_summaries_for(progresses)
    progresses = Array(progresses)
    return {} if progresses.empty?

    deal_ids = progresses.map(&:deal_id).uniq
    user_ids = progresses.map(&:user_id).uniq
    grouped = DealPresentationEvent
              .where(deal_id: deal_ids, user_id: user_ids)
              .order(:occurred_at)
              .group_by { |event| [event.deal_id, event.user_id] }

    progresses.each_with_object({}) do |progress, hash|
      events = (grouped[[progress.deal_id, progress.user_id]] || []).reject { |event| preview_event?(event) }
      hash[progress.id] = build_journey_summary(events)
    end
  end

  def self.build_journey_summary(events)
    step = "registered"
    last = nil

    Array(events).each do |event|
      mapped = JOURNEY_EVENT_STEPS[event.event_type]
      next if mapped.blank?

      step = mapped if JOURNEY_STEP_INDEX[mapped].to_i >= JOURNEY_STEP_INDEX[step].to_i
      last = event
    end

    {
      step: step,
      step_index: JOURNEY_STEP_INDEX[step],
      last_event: last,
      last_at: last&.occurred_at,
      last_page: last&.page_number,
      last_label: last&.label.presence || last&.topic.presence
    }
  end

  def self.preview_event?(event)
    meta = event.metadata
    meta.is_a?(Hash) && ActiveModel::Type::Boolean.new.cast(meta["preview"] || meta[:preview])
  end
  private_class_method :build_journey_summary, :preview_event?
end
