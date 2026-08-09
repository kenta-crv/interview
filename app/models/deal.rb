# app/models/deal.rb
class Deal < ApplicationRecord
  MAX_SUPPLEMENT_DOCUMENTS = 3

  belongs_to :client, optional: true
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

  validates :title, presence: true
  validates :client_id, presence: true, unless: :managed_by_admin?
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
    "female" => "marin",
    "male" => "ash"
  }.freeze

  DEFAULT_TTS_VOICE_GENDER = "female"
  ROLE_CLOSING_MARKER = '【次のステップ】'.freeze

  SYSTEM_FAQ_SOURCES = %w[ai_gap template supplement_pdf session_log stress_test checklist].freeze

  VISITOR_INFO_FIELD_MODES = %w[hidden optional required].freeze
  VISITOR_USER_FIELDS = %w[company name job_title email tel address url].freeze
  VISITOR_PROGRESS_FIELDS = %w[consideration_phase planned_introduction_date key_points_for_application].freeze
  VISITOR_INFO_FIELD_KEYS = (VISITOR_USER_FIELDS + VISITOR_PROGRESS_FIELDS).freeze

  DEFAULT_VISITOR_INFO_FIELDS = {
    "company" => "required",
    "name" => "required",
    "job_title" => "required",
    "email" => "required",
    "tel" => "optional",
    "address" => "optional",
    "url" => "optional",
    "consideration_phase" => "optional",
    "planned_introduction_date" => "optional",
    "key_points_for_application" => "optional"
  }.freeze

  VISITOR_INFO_FIELD_LABELS = {
    "company" => "会社名",
    "name" => "お名前",
    "job_title" => "役職",
    "email" => "メールアドレス",
    "tel" => "電話番号",
    "address" => "住所",
    "url" => "WebサイトURL",
    "consideration_phase" => "ご検討の状況",
    "planned_introduction_date" => "導入予定日",
    "key_points_for_application" => "決め手になるポイント"
  }.freeze

  validates :tts_voice_gender, inclusion: { in: TTS_VOICE_GENDERS.keys }

  def openai_tts_voice
    OPENAI_TTS_VOICE_BY_GENDER[tts_voice_gender.presence || DEFAULT_TTS_VOICE_GENDER] ||
      OPENAI_TTS_VOICE_BY_GENDER[DEFAULT_TTS_VOICE_GENDER]
  end

  def presentation_cta_payload
    {
      'label' => presentation_cta_label.presence || DEFAULT_CTA_LABEL,
      'url' => presentation_cta_url.to_s,
      'sales_url' => follow_up_sales_url.to_s,
      'exit_contract_label' => exit_contract_label.presence || DEFAULT_EXIT_CONTRACT_LABEL,
      'exit_sales_call_label' => exit_sales_call_label.presence || DEFAULT_EXIT_SALES_CALL_LABEL
    }
  end

  def resolved_visitor_info_fields
    stored = visitor_info_fields.is_a?(Hash) ? visitor_info_fields.stringify_keys : {}
    DEFAULT_VISITOR_INFO_FIELDS.merge(stored.slice(*VISITOR_INFO_FIELD_KEYS)).transform_values do |mode|
      VISITOR_INFO_FIELD_MODES.include?(mode.to_s) ? mode.to_s : "hidden"
    end
  end

  def visitor_info_field_mode(key)
    resolved_visitor_info_fields[key.to_s] || "hidden"
  end

  def visitor_info_field_visible?(key)
    visitor_info_field_mode(key) != "hidden"
  end

  def visitor_info_field_required?(key)
    visitor_info_field_mode(key) == "required"
  end

  def visitor_registration_required?
    !skip_visitor_registration? && visible_visitor_info_fields.any?
  end

  def visible_visitor_info_fields
    VISITOR_INFO_FIELD_KEYS.select { |key| visitor_info_field_visible?(key) }
  end

  def required_visitor_info_fields
    VISITOR_INFO_FIELD_KEYS.select { |key| visitor_info_field_required?(key) }
  end

  def assign_visitor_info_fields!(raw_fields)
    raw = if raw_fields.respond_to?(:to_unsafe_h)
            raw_fields.to_unsafe_h
          elsif raw_fields.respond_to?(:to_h)
            raw_fields.to_h
          else
            {}
          end
    raw = raw.stringify_keys

    normalized = {}
    VISITOR_INFO_FIELD_KEYS.each do |key|
      mode = raw[key].presence
      normalized[key] = VISITOR_INFO_FIELD_MODES.include?(mode.to_s) ? mode.to_s : DEFAULT_VISITOR_INFO_FIELDS[key]
    end
    self.visitor_info_fields = normalized
  end

  def materials_download_payload
    doc = deal_documents.proposals.order(:created_at).reverse_order.detect { |d| d.file.attached? }
    return nil unless doc

    {
      'label' => '使用資料をダウンロード',
      'url' => Rails.application.routes.url_helpers.rails_blob_path(doc.file, disposition: 'attachment', only_path: true),
      'filename' => doc.file.filename.to_s
    }
  end

  def page_role_for(page)
    menu = menu_items_list.find { |item| item['page_number'].to_i == page.page_number }
    primary = [
      menu&.dig('key'),
      menu&.dig('label'),
      page.title
    ].compact.join(' ')

    return 'pricing' if primary.match?(/料金|費用|価格|プラン|月額|pricing|price|plan|roi/i)
    return 'flow' if primary.match?(/導入|フロー|手順|オンボーディング|契約フロー|flow|onboard|contract.?flow/i)

    # タイトル等が曖昧なときだけ本文の先頭を弱く参照（会社概要の「導入しやすい」等で誤判定しない）
    excerpt = page.script.to_s[0, 80]
    return 'pricing' if excerpt.match?(/料金|費用|価格|プラン|月額/)
    return 'flow' if excerpt.match?(/導入フロー|契約フロー|オンボーディング|導入手順|導入の流れ/)

    nil
  end

  def role_closing_text_for(role)
    if language == 'ja'
      case role.to_s
      when 'pricing'
        "#{ROLE_CLOSING_MARKER}料金面でも導入しやすい設計です。まずはトライアルで効果をご確認いただくことも可能です。ご希望でしたらこのまま契約（トライアル）へお進みください。より詳細な条件のご案内が必要でしたら、担当者よりご説明します。"
      when 'flow'
        "#{ROLE_CLOSING_MARKER}導入までの流れは以上です。スムーズに始められるようサポートいたします。このままお申し込みを進めるか、担当者に詳細をご相談ください。"
      else
        nil
      end
    else
      case role.to_s
      when 'pricing'
        "#{ROLE_CLOSING_MARKER} Our pricing is designed to make adoption easy. You can also start with a trial. Choose contract or trial to proceed, or talk with our team for tailored details."
      when 'flow'
        "#{ROLE_CLOSING_MARKER} That covers the onboarding flow. We support a smooth start. Continue to apply, or speak with our team for more detail."
      else
        nil
      end
    end
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

  def proposal_upload_locked?
    deal_documents.proposals.exists?
  end

  def supplement_upload_limit_reached?
    deal_documents.supplements.count >= MAX_SUPPLEMENT_DOCUMENTS
  end

  def supplement_uploads_remaining
    [MAX_SUPPLEMENT_DOCUMENTS - deal_documents.supplements.count, 0].max
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

    stored_by_page = menu_items_list.each_with_object({}) do |item, memo|
      page_number = item['page_number'].to_i
      next if page_number <= 0
      memo[page_number] = item
    end

    # 保存済みメニューが少なくても、表紙以外の全ページを下部ボタンにする
    pages.filter_map do |page|
      next if cover_page?(page)

      item = stored_by_page[page.page_number] || {}
      label = item['label'] || item[:label]
      label = page.title if generic_menu_label?(label)

      {
        'key' => (item['key'] || item[:key] || "page_#{page.page_number}").to_s,
        'label' => label.presence || page.title.presence || "スライド #{page.page_number}",
        'page_number' => page.page_number
      }
    end.sort_by { |item| item['page_number'].to_i }
  end

  def presentation_opening_payload
    pages = deal_pages.order(:page_number)
    company_page = pages.find { |p| p.page_number > 1 }&.page_number || pages.first&.page_number || 1
    last_page = pages.last&.page_number || 1

    {
      'greeting_audio' => opening_speech_url('greeting'),
      'company_overview_audio' => opening_speech_url('company_overview'),
      'usage_guide_audio' => opening_speech_url('usage_guide'),
      'closing_audio' => opening_speech_url('closing'),
      'greeting_page' => pages.first&.page_number || 1,
      'company_page' => company_page,
      'closing_page' => last_page,
      'greeting_text' => greeting_script.presence || default_greeting_text,
      'company_overview_text' => company_overview_script.presence || default_company_overview_text,
      'usage_guide_text' => usage_guide_script.presence || default_usage_guide_text,
      'closing_text' => closing_script.presence || default_closing_text
    }
  end

  def presentation_closing_payload
    {
      'text' => closing_script.presence || default_closing_text,
      'audio_url' => opening_speech_url('closing'),
      'page_number' => deal_pages.order(:page_number).last&.page_number || 1
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
    if language == 'ja'
      '進め方は3つです。1つ目は、気になる点を自由にご質問ください。2つ目は、下のメニューから知りたいトピックを選んでください。3つ目は、ご指定がない場合、このまま進行させていただきます。'
    else
      'There are three ways to proceed. First, ask any questions freely. Second, choose a topic from the menu below. Third, if you do not specify, I will continue through the materials in order.'
    end
  end

  def default_closing_text
    if language == 'ja'
      'ここまでのご案内を踏まえ、改めて本サービスの魅力をお伝えします。導入しやすく、確かな価値を感じていただける内容です。このまま契約またはトライアルへ進むことも、担当者より詳細をご案内することも可能です。ご希望の進め方をお選びください。'
    else
      'Based on what we covered, here is the key value once more: easy to adopt, with clear results. You can proceed to contract or trial now, or speak with our team for a detailed walkthrough. Please choose how you would like to continue.'
    end
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
      closing: { text: closing_script.presence || default_closing_text, audio_url: opening_speech_url('closing') },
      menu_items: menu_items_list,
      pages: deal_pages.order(:page_number).map do |page|
        {
          page_number: page.page_number,
          title: page.title,
          script: page.script,
          audio_url: page_audio_path(page),
          role: page_role_for(page)
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
    pages.reject { |page| cover_page?(page) }.map do |page|
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
      unless doc.file_readable?
        Rails.logger.warn("Skipping unreadable deal_document=#{doc.id} deal=#{id} filename=#{doc.filename}")
        next
      end

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