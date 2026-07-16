# app/models/deal.rb
class Deal < ApplicationRecord
  belongs_to :client
  has_many :deal_documents, dependent: :destroy
  has_many :deal_audios, dependent: :destroy
  has_many :deal_speeches, dependent: :destroy
  has_many :deal_presentations, dependent: :destroy
  has_many :deal_pages, dependent: :destroy
  has_one :deal_transcript, dependent: :destroy
  has_one :deal_summary, dependent: :destroy
  has_many :user_progresses, dependent: :destroy
  has_many :deal_evaluations, dependent: :destroy
  has_many :deal_presentation_events, dependent: :destroy
  has_many :deal_faqs, dependent: :destroy
  has_many :deal_follow_up_templates, dependent: :destroy

  include DealFollowUpTemplateDefaults

  enum status: {
    uploading: 0,
    processing: 1,
    transcribing: 2,
    summarizing: 3,
    completed: 4,
    failed: 5
  }

  enum language: {
    en: 'en',
    ja: 'ja'
  }

  validates :client_id, :title, presence: true
  validates :language, presence: true

  scope :by_client, ->(client) { where(client: client) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_token, ->(token) { where(access_token: token) }

  def publicly_accessible?
    playback_ready? && deal_pages.exists?
  end

  def record_public_page_view!
    return false unless publicly_accessible?

    self.class.increment_counter(:page_views_count, id)
    true
  end

  before_create :generate_access_token
  after_create :ensure_follow_up_templates!

  DEFAULT_CONVERSATION_TOPICS = [
    { 'key' => 'overview', 'label' => 'サービス概要', 'page_number' => 1 },
    { 'key' => 'pricing', 'label' => '料金プラン', 'page_number' => 2 },
    { 'key' => 'trial', 'label' => 'トライアル', 'page_number' => 3 },
    { 'key' => 'contract', 'label' => '契約フロー', 'page_number' => 4 }
  ].freeze

  DEFAULT_CTA_LABEL = "契約を進める".freeze
  DEFAULT_EXIT_CONTRACT_LABEL = "契約へ進む".freeze
  DEFAULT_EXIT_SALES_CALL_LABEL = "担当者と商談を希望".freeze

  TTS_VOICE_GENDERS = {
    "female" => "女性",
    "male" => "男性"
  }.freeze

  OPENAI_TTS_VOICE_BY_GENDER = {
    "female" => "coral",
    "male" => "ash"
  }.freeze

  DEFAULT_TTS_VOICE_GENDER = "female"

  SYSTEM_FAQ_SOURCES = %w[ai_gap template supplement_pdf session_log stress_test checklist].freeze

  validates :tts_voice_gender, inclusion: { in: TTS_VOICE_GENDERS.keys }

  def openai_tts_voice
    OPENAI_TTS_VOICE_BY_GENDER[tts_voice_gender.presence || DEFAULT_TTS_VOICE_GENDER] ||
      OPENAI_TTS_VOICE_BY_GENDER[DEFAULT_TTS_VOICE_GENDER]
  end

  def presentation_cta_payload
    {
      'label' => presentation_cta_label.presence || DEFAULT_CTA_LABEL,
      'url' => presentation_cta_url.to_s,
      'exit_contract_label' => exit_contract_label.presence || DEFAULT_EXIT_CONTRACT_LABEL,
      'exit_sales_call_label' => exit_sales_call_label.presence || DEFAULT_EXIT_SALES_CALL_LABEL
    }
  end

  def approved_faqs_for_conversation
    deal_faqs.for_conversation.ordered
  end

  def faq_context_for_prompt
    approved_faqs_for_conversation.map do |faq|
      "Q: #{faq.question}\nA: #{faq.answer}"
    end.join("\n\n")
  end

  def knowledge_coverage_percent
    suggested = deal_faqs.where(source: SYSTEM_FAQ_SOURCES).where.not(status: "skipped")
    return 100 if suggested.empty?

    answered = suggested.where(status: "approved").where.not(answer: [nil, ""]).count
    ((answered.to_f / suggested.count) * 100).round
  end

  def unanswered_free_text_questions(limit: 20)
    messages = deal_presentation_events
      .where(event_type: "free_text_send")
      .where.not(message: [nil, ""])
      .order(occurred_at: :desc)
      .limit(limit)
      .pluck(:message)
      .uniq

    messages.reject do |message|
      deal_faqs.exists?(["question LIKE ?", "%#{message.to_s.truncate(30)}%"])
    end
  end

  def pending_faq_count
    deal_faqs.pending.count
  end

  def low_knowledge_coverage?
    knowledge_coverage_percent < 70
  end

  def menu_items_for_conversation
    items = presentation_menu_items
    items.any? ? items : DEFAULT_CONVERSATION_TOPICS
  end

  def presentation_opening_segments
    payload = presentation_opening_payload
    guide_page = payload['company_page']

    [
      {
        'page_number' => payload['greeting_page'],
        'title' => 'ご挨拶',
        'text' => payload['greeting_text'],
        'audio_url' => payload['greeting_audio']
      },
      {
        'page_number' => payload['company_page'],
        'title' => '会社概要',
        'text' => payload['company_overview_text'],
        'audio_url' => payload['company_overview_audio']
      },
      {
        'page_number' => guide_page,
        'title' => 'ご案内',
        'text' => usage_guide_script.presence || default_usage_guide_text,
        'audio_url' => opening_speech_url('usage_guide')
      }
    ]
  end

  def presentation_menu_items
    pages = deal_pages.order(:page_number)
    return [] if pages.empty?

    items = menu_items_list
    source = items.any? ? items : pages_for_menu(pages)

    source.filter_map do |item|
      page_number = item['page_number'].to_i
      page = pages.find { |p| p.page_number == page_number }
      next unless page
      next if cover_page?(page)

      label = item['label'] || item[:label]
      label = page.title if generic_menu_label?(label)

      {
        'key' => (item['key'] || item[:key] || "page_#{page.page_number}").to_s,
        'label' => label.presence || page.title.presence || "スライド #{page.page_number}",
        'page_number' => page.page_number
      }
    end
  end

  def presentation_opening_payload
    pages = deal_pages.order(:page_number)
    company_page = pages.find { |p| p.page_number > 1 }&.page_number || pages.first&.page_number || 1

    {
      'greeting_audio' => opening_speech_url('greeting'),
      'company_overview_audio' => opening_speech_url('company_overview'),
      'usage_guide_audio' => opening_speech_url('usage_guide'),
      'greeting_page' => pages.first&.page_number || 1,
      'company_page' => company_page,
      'greeting_text' => greeting_script.presence || default_greeting_text,
      'company_overview_text' => company_overview_script.presence || default_company_overview_text,
      'usage_guide_text' => usage_guide_script.presence || default_usage_guide_text
    }
  end

  def conversation_opening_messages
    [
      {
        content: greeting_script.presence || default_greeting_text,
        audio_url: opening_speech_url('greeting')
      },
      {
        content: company_overview_script.presence || default_company_overview_text,
        audio_url: opening_speech_url('company_overview')
      },
      {
        content: usage_guide_script.presence || default_usage_guide_text,
        audio_url: opening_speech_url('usage_guide')
      }
    ]
  end

  def default_greeting_text
    language == 'ja' ? "こんにちは。#{title}のAI商談アシスタントです。本日はお時間をいただきありがとうございます。" : "Hello! I'm the AI assistant for #{title}."
  end

  def default_company_overview_text
    deal_summary&.summary.presence || description.presence || (language == 'ja' ? '資料に基づき、サービス内容をご案内します。' : 'I will guide you through our proposal.')
  end

  def default_usage_guide_text
    language == 'ja' ? '知りたいトピックをメニューからお選びください。自由にご質問いただくこともできます。' : 'Please select a topic or ask a question freely.'
  end

  def opening_speech_url(kind)
    speech = deal_speeches.find_by(voice: kind.to_s)
    inline_audio_path(speech&.audio_file)
  end

  def inline_audio_path(attachment)
    return nil unless attachment&.attached?

    path = Rails.application.routes.url_helpers.rails_blob_path(
      attachment,
      only_path: true
    )
    "#{path}?v=#{attachment.blob.checksum}"
  end

  def page_audio_path(page)
    inline_audio_path(page.page_audio) || page.audio_url
  end

  def menu_items_list
    items = parse_stored_menu_items
    return items if items.any?

    pages_for_menu(deal_pages.order(:page_number))
  end

  def playback_payload
    {
      greeting: { text: greeting_script, audio_url: opening_speech_url('greeting') },
      company_overview: { text: company_overview_script, audio_url: opening_speech_url('company_overview') },
      usage_guide: { text: usage_guide_script, audio_url: opening_speech_url('usage_guide') },
      menu_items: menu_items_list,
      pages: deal_pages.order(:page_number).map do |page|
        {
          page_number: page.page_number,
          title: page.title,
          script: page.script,
          audio_url: page_audio_path(page)
        }
      end,
      playback_ready: playback_ready
    }
  end

  # Deal methods
  def start_processing!
    update!(status: :processing, started_at: Time.current)
  end

  def complete!
    update!(status: :completed, completed_at: Time.current)
  end

  def fail!
    update!(status: :failed, completed_at: Time.current)
  end

  def duration
    return nil unless started_at && completed_at
    (completed_at - started_at).to_i
  end

  # DealAudio methods (consolidated)
  def file_size_mb
    deal_audios.first&.file_size_mb
  end

  def duration_minutes
    deal_audios.first&.duration_minutes
  end

  # DealDocument methods (consolidated)
  def document_file_size_mb
    deal_documents.first&.file_size_mb
  end

  # DealSegment methods (consolidated)
  def segment_duration_minutes
    deal_audios.first&.deal_segments&.first&.duration_minutes
  end

  # DealTranscript methods (consolidated)
  def total_duration_minutes
    return nil unless deal_transcript&.total_duration_seconds
    (deal_transcript.total_duration_seconds.to_f / 60).round(2)
  end

  # Simplified processing without ffmpeg - uses Claude API directly
  def process_with_claude!
    start_processing!

    begin
      # Collect raw document files
      documents = collect_documents

      # Use Claude API to analyze PDFs directly
      Rails.logger.info("🤖 Processing deal #{id} with Claude API")
      result = generate_claude_summary_from_documents(documents)

      # Create transcript and summary
      create_transcript_and_summary(result[:transcript], result[:summary])

      complete!
      Rails.logger.info("✅ Deal #{id} processing completed successfully")
    rescue => e
      fail!
      Rails.logger.error("❌ Deal #{id} processing failed: #{e.message}")
      raise
    end
  end

  private

  def pages_for_menu(pages)
    pages.reject { |page| cover_page?(page) }.first(6).map do |page|
      {
        'key' => "page_#{page.page_number}",
        'label' => page.title.presence || "スライド #{page.page_number}",
        'page_number' => page.page_number
      }
    end
  end

  def parse_stored_menu_items
    raw = menu_items
    list = case raw
           when Array then raw
           when Hash
             raw['menu_items'] || raw[:menu_items] || [raw]
           else
             []
           end

    list.filter_map { |item| normalize_menu_item_entry(item) }
  end

  def normalize_menu_item_entry(item)
    return nil unless item.is_a?(Hash)

    page_number = item['page_number'] || item[:page_number]
    return nil if page_number.blank?

    {
      'key' => (item['key'] || item[:key] || "page_#{page_number}").to_s,
      'label' => (item['label'] || item[:label]).to_s,
      'page_number' => page_number.to_i
    }
  end

  def cover_page?(page)
    page.page_number == 1 && page.title.to_s.match?(/表紙|挨拶|cover/i)
  end

  def generic_menu_label?(label)
    label.to_s.match?(/前半|中盤|後半|提案内容/)
  end

  def collect_documents
    deal_documents.proposals.filter_map do |doc|
      next unless doc.file.attached?

      raw = doc.file.download
      content_type = doc.content_type

      {
        data: Base64.strict_encode64(raw),
        media_type: content_type.presence_in(%w[application/pdf image/jpeg image/png image/gif image/webp]) ? content_type : 'application/pdf',
        filename: doc.file.filename.to_s
      }
    end
  end

  def generate_claude_summary_from_documents(documents)
    api_key = ENV['ANTHROPIC_API_KEY']

    # Build message content: attach each document + prompt
    content = documents.map do |doc|
      {
        type: 'document',
        source: {
          type: 'base64',
          media_type: doc[:media_type],
          data: doc[:data]
        }
      }
    end

    content << { type: 'text', text: build_claude_prompt }

    uri = URI.parse('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = '2023-06-01'
    request['anthropic-beta'] = 'pdfs-2024-09-25'
    request.body = {
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 2048,
      messages: [{ role: 'user', content: content }]
    }.to_json

    response = http.request(request)
    body = JSON.parse(response.body)
    Rails.logger.info("Claude API response: #{body}")

    text = body.dig('content', 0, 'text') || ''

    summary = parse_summary_response(text)

    { transcript: text, summary: summary }
  rescue => e
    Rails.logger.error("Claude API call failed: #{e.message}")
    { transcript: '', summary: empty_summary }
  end

  def build_claude_prompt
    if language == 'ja'
      <<~PROMPT
        添付の資料を読み、商談の要約を作成してください。

        以下の形式でJSONのみを出力してください（前後に説明文や```は不要です）：
        {
          "summary": "商談の全体要約（200-300字）",
          "key_points": "重要なポイントを箇条書きで",
          "action_items": "アクションアイテムを箇条書きで",
          "participants": "参加者情報",
          "next_steps": "次のステップを箇条書きで"
        }
      PROMPT
    else
      <<~PROMPT
        Please read the attached documents and create a summary of the business meeting.

        Output only JSON in the following format (no explanation or ``` needed):
        {
          "summary": "Overall summary of the meeting (200-300 characters)",
          "key_points": "Key points in bullet points",
          "action_items": "Action items in bullet points",
          "participants": "Participant information",
          "next_steps": "Next steps in bullet points"
        }
      PROMPT
    end
  end

  def parse_summary_response(response)
    # ```json ... ``` ブロックがあれば除去
    cleaned = response.gsub(/```json\s*/i, '').gsub(/```/, '').strip
    parsed = JSON.parse(cleaned)

    {
      summary: parsed['summary'] || '',
      key_points: format_array_or_string(parsed['key_points']),
      action_items: format_array_or_string(parsed['action_items']),
      participants: parsed['participants'] || '',
      next_steps: format_array_or_string(parsed['next_steps'])
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse summary response: #{e.message}")
    { summary: response, key_points: '', action_items: '', participants: '', next_steps: '' }
  end

  def format_array_or_string(value)
    case value
    when Array
      value.map { |v| "・#{v}" }.join("\n")
    when String
      value
    else
      ''
    end
  end

  def build_transcript_text(summary)
    if language == 'ja'
      <<~TEXT
        【要約】
        #{summary[:summary]}

        【重要ポイント】
        #{summary[:key_points]}

        【アクションアイテム】
        #{summary[:action_items]}

        【参加者】
        #{summary[:participants]}

        【次のステップ】
        #{summary[:next_steps]}
      TEXT
    else
      <<~TEXT
        [Summary]
        #{summary[:summary]}

        [Key Points]
        #{summary[:key_points]}

        [Action Items]
        #{summary[:action_items]}

        [Participants]
        #{summary[:participants]}

        [Next Steps]
        #{summary[:next_steps]}
      TEXT
    end
  end

  def create_transcript_and_summary(transcript, summary)
    DealTranscript.create!(
      deal: self,
      full_transcript: build_transcript_text(summary),
      segment_count: 1,
      total_duration_seconds: 0
    )

    DealSummary.create!(
      deal: self,
      summary: summary[:summary],
      key_points: summary[:key_points],
      action_items: summary[:action_items],
      participants: summary[:participants],
      next_steps: summary[:next_steps]
    )
  end

  def empty_summary
    { summary: '', key_points: '', action_items: '', participants: '', next_steps: '' }
  end

  private

  def generate_access_token
    self.access_token = loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless Deal.exists?(access_token: token)
    end
  end
end