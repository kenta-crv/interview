class DealPresentationEvent < ApplicationRecord
  belongs_to :deal
  belongs_to :user, optional: true
  belongs_to :user_progress, optional: true

  EVENT_TYPES = %w[
    presentation_start
    topic_click
    free_text_send
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
    'chat_toggle' => 'チャット開閉',
    'page_view' => 'ページ閲覧',
    'session_close' => '離脱',
    'evaluation_submit' => '評価送信',
    'cta_click' => 'CTAボタン',
    'exit_contract_click' => '終了：契約へ進む',
    'exit_sales_call_click' => '終了：担当者商談希望'
  }.freeze

  validates :session_key, :event_type, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }

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
end
