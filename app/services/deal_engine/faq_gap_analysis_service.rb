module DealEngine
  class FaqGapAnalysisService
    STANDARD_QUESTIONS = [
      { category: "pricing", question: "料金プランや初期費用・月額費用を教えてください" },
      { category: "implementation", question: "導入期間と必要な社内リソースを教えてください" },
      { category: "security", question: "セキュリティやデータの取り扱いについて教えてください" },
      { category: "comparison", question: "競合サービスや代替手段との違いを教えてください" },
      { category: "support", question: "導入後のサポート体制を教えてください" },
      { category: "contract", question: "契約期間・解約条件・更新条件を教えてください" },
      { category: "pricing", question: "ROIや費用対効果の根拠を教えてください" },
      { category: "implementation", question: "既存システムとの連携方法を教えてください" }
    ].freeze

    def initialize(deal, client: nil, limit: nil)
      @deal = deal
      @client = client || deal.client
      @limit = limit || gap_limit_for_client
    end

    def analyze!
      return { created: 0, skipped: true, reason: "no_summary" } unless @deal.deal_summary.present?

      suggestions = fetch_suggestions
      created = persist_suggestions(suggestions)
      { created: created, suggestions: suggestions.size }
    end

    private

    def gap_limit_for_client
      @client.gap_analysis_question_limit
    end

    def fetch_suggestions
      ai_suggestions = fetch_ai_suggestions
      return ai_suggestions.first(@limit) if ai_suggestions.any?

      fallback_heuristic_suggestions.first(@limit)
    end

    def fetch_ai_suggestions
      api_key = ENV["OPENAI_API_KEY"]
      return [] if api_key.blank?

      summary = @deal.deal_summary
      existing = @deal.deal_faqs.pluck(:question).join("\n")
      pages = @deal.deal_pages.order(:page_number).limit(8).map { |p| "P#{p.page_number} #{p.title}: #{p.script.to_s.truncate(200)}" }.join("\n")

      prompt = if @deal.language == "ja"
        <<~PROMPT
          あなたはB2B商談のナレッジギャップ分析担当です。
          以下の提案資料を読み、Buyerが商談中に聞きそうだが資料だけでは答えにくい質問を#{@limit}件以内で提案してください。
          既存FAQと重複する質問は除外してください。
          JSON配列のみ返してください。形式: [{"category":"pricing|implementation|security|comparison|support|contract|other","question":"..."}]

          【要約】
          #{summary.summary}
          #{summary.key_points}

          【スライド】
          #{pages}

          【既存FAQ】
          #{existing.presence || "なし"}
        PROMPT
      else
        <<~PROMPT
          Analyze the proposal and suggest up to #{@limit} buyer questions poorly covered by materials.
          Return JSON array only: [{"category":"...","question":"..."}]

          Summary: #{summary.summary}
          Slides: #{pages}
          Existing FAQ: #{existing.presence || "none"}
        PROMPT
      end

      uri = URI.parse("https://api.openai.com/v1/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{api_key}"
      request.body = {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 800,
        temperature: 0.4
      }.to_json

      response = http.request(request)
      body = JSON.parse(response.body)
      content = body.dig("choices", 0, "message", "content").to_s
      json = content[/\[[\s\S]*\]/]
      return [] if json.blank?

      parsed = JSON.parse(json)
      parsed.filter_map do |item|
        next unless item.is_a?(Hash)

        category = item["category"].to_s
        category = "other" unless DealFaq::CATEGORIES.key?(category)
        question = item["question"].to_s.strip
        next if question.blank?

        { category: category, question: question }
      end
    rescue => e
      Rails.logger.error("FaqGapAnalysisService AI error: #{e.message}")
      []
    end

    def fallback_heuristic_suggestions
      summary_text = [@deal.deal_summary&.summary, @deal.deal_summary&.key_points].join(" ")
      existing_questions = @deal.deal_faqs.pluck(:question)

      STANDARD_QUESTIONS.reject do |item|
        existing_questions.any? { |q| similar_question?(q, item[:question]) } ||
          covered_in_summary?(summary_text, item)
      end
    end

    def covered_in_summary?(summary_text, item)
      keywords = {
        "pricing" => %w[料金 費用 価格 プラン 月額 ROI],
        "implementation" => %w[導入 期間 体制 リソース 連携],
        "security" => %w[セキュリティ データ 暗号 コンプライアンス],
        "comparison" => %w[競合 比較 違い 優位],
        "support" => %w[サポート 保守 問い合わせ],
        "contract" => %w[契約 解約 更新 最低]
      }[item[:category]] || []

      keywords.count { |word| summary_text.include?(word) } >= 2
    end

    def similar_question?(a, b)
      normalize(a) == normalize(b) || normalize(a).include?(normalize(b)[0, 8])
    end

    def normalize(text)
      text.to_s.gsub(/\s+/, "")
    end

    def persist_suggestions(suggestions)
      created = 0
      base_position = @deal.deal_faqs.maximum(:position).to_i + 1

      suggestions.each_with_index do |item, index|
        next if @deal.deal_faqs.exists?(["question = ?", item[:question]])

        @deal.deal_faqs.create!(
          question: item[:question],
          category: item[:category],
          source: "ai_gap",
          status: "pending",
          position: base_position + index
        )
        created += 1
      end

      created
    end
  end
end
