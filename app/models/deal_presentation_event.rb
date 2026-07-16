class DealPresentationEvent < ApplicationRecord
  belongs_to :deal
  belongs_to :user, optional: true
  belongs_to :user_progress, optional: true

  EVENT_TYPES = %w[
    presentation_start
    topic_click
    free_text_send
    ai_reply
    chat_toggle
    page_view
    session_close
    evaluation_submit
    cta_click
    exit_contract_click
    exit_sales_call_click
  ].freeze

  EVENT_LABELS = {
    'presentation_start' => 'プレゼン開始',
    'topic_click' => 'トピッククリック',
    'free_text_send' => '自由入力',
    'ai_reply' => 'AI回答',
    'chat_toggle' => 'チャット開閉',
    'page_view' => 'ページ閲覧',
    'session_close' => '離脱',
    'evaluation_submit' => '評価送信',
    'cta_click' => 'CTAボタン',
    'exit_contract_click' => '終了：契約へ進む',
    'exit_sales_call_click' => '終了：担当者商談希望'
  }.freeze

  FOLLOW_UP_TRIGGER_EVENT = "session_close"

  validates :session_key, :event_type, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }

  after_create_commit :enqueue_session_analysis, if: :session_analysis_trigger?
  after_create_commit :enqueue_follow_up_campaign, if: :follow_up_trigger?

  scope :recent_first, -> { order(occurred_at: :desc) }
  scope :for_session, ->(key) { where(session_key: key) }

  def display_event_type
    EVENT_LABELS[event_type] || event_type
  end

  def self.log!(deal:, session_key:, event_type:, user: nil, user_progress: nil, **attrs)
    create!(
      {
        deal: deal,
        user: user,
        user_progress: user_progress,
        session_key: session_key,
        event_type: event_type,
        occurred_at: Time.current
      }.merge(attrs)
    )
  end

  private

  def session_analysis_trigger?
    event_type == FOLLOW_UP_TRIGGER_EVENT &&
      user_progress.present? &&
      !preview_event?
  end

  def follow_up_trigger?
    event_type == FOLLOW_UP_TRIGGER_EVENT &&
      user_progress.present? &&
      !preview_event? &&
      evaluated_session_close?
  end

  def evaluated_session_close?
    metadata.is_a?(Hash) && metadata["evaluated"] == true
  end

  def preview_event?
    metadata.is_a?(Hash) && metadata["preview"]
  end

  def enqueue_session_analysis
    AnalyzeUserProgressSessionJob.perform_later(user_progress_id)
  end

  def enqueue_follow_up_campaign
    DealFollowUp::EnqueueCampaignService.call(
      user_progress: user_progress,
      ended_at: occurred_at
    )
  end
end
