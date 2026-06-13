# app/jobs/generate_deal_summary_job.rb
class GenerateDealSummaryJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(deal_id)
    deal = Deal.find(deal_id)

    # べき等性チェック: 既に要約が存在する場合はスキップ
    return if deal.deal_summary.present?

    deal.update!(status: :summarizing)

    transcript = deal.deal_transcript
    unless transcript
      deal.update!(status: :failed)
      Rails.logger.error("No transcript found for deal #{deal.id}")
      return
    end

    # 資料の内容を取得
    documents_content = extract_documents_content(deal)

    begin
      # 既存のLLMClientを使用して要約生成
      language = deal.language || 'ja'
      summary = generate_summary(transcript.full_transcript, documents_content, language)

      DealSummary.create!(
        deal: deal,
        summary: summary[:summary],
        key_points: summary[:key_points],
        action_items: summary[:action_items],
        participants: summary[:participants],
        next_steps: summary[:next_steps]
      )

      deal.complete!
      Rails.logger.info("✅ Deal #{deal.id} summary generated successfully")
    rescue => e
      deal.fail!
      Rails.logger.error("❌ Deal #{deal.id} summary generation failed: #{e.message}")
      raise
    end
  end

  private

  def extract_documents_content(deal)
    deal.deal_documents.map do |doc|
      if doc.file.attached?
        doc.file.download
      else
        ""
      end
    end.join("\n\n")
  end

  def generate_summary(transcript, documents_content, language)
    llm_client = InterviewEngine::LLMClient.new

    prompt = build_summary_prompt(transcript, documents_content, language)

    response = llm_client.chat(prompt)

    parse_summary_response(response)
  end

  def build_summary_prompt(transcript, documents_content, language)
    base_prompt = if language == 'ja'
      <<~PROMPT
        以下は商談の文字起こしと関連資料です。これらを基に要約を作成してください。

        === 資料 ===
        #{documents_content}

        === 文字起こし ===
        #{transcript}

        以下の形式でJSONで出力してください：
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
        Below is the transcript of a business meeting and related documents. Please create a summary based on these.

        === Documents ===
        #{documents_content}

        === Transcript ===
        #{transcript}

        Please output in the following JSON format:
        {
          "summary": "Overall summary of the meeting (200-300 characters)",
          "key_points": "Key points in bullet points",
          "action_items": "Action items in bullet points",
          "participants": "Participant information",
          "next_steps": "Next steps in bullet points"
        }
      PROMPT
    end

    base_prompt
  end

  def parse_summary_response(response)
    # JSONレスポンスをパース
    parsed = JSON.parse(response)

    {
      summary: parsed['summary'] || '',
      key_points: parsed['key_points'] || '',
      action_items: parsed['action_items'] || '',
      participants: parsed['participants'] || '',
      next_steps: parsed['next_steps'] || ''
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse summary response: #{e.message}")
    # フォールバック: レスポンスをそのまま要約として使用
    {
      summary: response,
      key_points: '',
      action_items: '',
      participants: '',
      next_steps: ''
    }
  end
end
