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

  before_create :generate_access_token

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

  def collect_documents
    deal_documents.filter_map do |doc|
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