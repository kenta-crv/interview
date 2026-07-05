module DealEngine
  class BuyerStressTestService
    TOUGH_QUESTION_SEEDS = [
      { category: "pricing", question: "なぜ競合より高いのですか？具体的なROI根拠は？" },
      { category: "implementation", question: "導入失敗時のリスクと撤退条件を教えてください" },
      { category: "security", question: "情報漏洩が起きた場合の責任範囲と補償は？" },
      { category: "contract", question: "最低契約期間と解約ペナルティはありますか？" },
      { category: "comparison", question: "自社で内製する場合との比較優位は何ですか？" },
      { category: "support", question: "担当者が変わった場合の引き継ぎ体制は？" }
    ].freeze

    def initialize(deal, client: nil, limit: nil)
      @deal = deal
      @client = client || deal.client
      @limit = limit || @client.stress_test_question_limit
    end

    def run!
      questions = fetch_questions
      weak = []
      created = 0
      base_position = @deal.deal_faqs.maximum(:position).to_i + 1

      questions.each_with_index do |item, index|
        next if @deal.deal_faqs.exists?(["question = ?", item[:question]])

        if covered?(item[:question])
          next
        end

        weak << item
        @deal.deal_faqs.create!(
          question: item[:question],
          category: item[:category],
          source: "stress_test",
          status: "pending",
          position: base_position + index
        )
        created += 1
      end

      { created: created, weak_count: weak.size, tested: questions.size }
    end

    private

    def fetch_questions
      ai_questions = fetch_ai_questions
      list = ai_questions.presence || TOUGH_QUESTION_SEEDS
      list.first(@limit)
    end

    def fetch_ai_questions
      api_key = ENV["OPENAI_API_KEY"]
      return [] if api_key.blank? || @deal.deal_summary.blank?

      summary = @deal.deal_summary
      prompt = <<~PROMPT
        「#{@deal.title}」の商談資料に対し、厳しいBuyerが突っ込む質問を#{@limit}件提案してください。
        資料だけでは答えにくいものを優先。JSON配列のみ:
        [{"category":"pricing|implementation|security|comparison|support|contract|other","question":"..."}]

        要約: #{summary.summary}
        要点: #{summary.key_points}
      PROMPT

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
        temperature: 0.5
      }.to_json

      response = http.request(request)
      body = JSON.parse(response.body)
      content = body.dig("choices", 0, "message", "content").to_s
      json = content[/\[[\s\S]*\]/]
      return [] if json.blank?

      JSON.parse(json).filter_map do |item|
        category = item["category"].to_s
        category = "other" unless DealFaq::CATEGORIES.key?(category)
        question = item["question"].to_s.strip
        next if question.blank?

        { category: category, question: question }
      end
    rescue => e
      Rails.logger.error("BuyerStressTestService AI error: #{e.message}")
      []
    end

    def covered?(question)
      normalized = question.gsub(/\s+/, "")
      @deal.deal_faqs.for_conversation.any? do |faq|
        faq_q = faq.question.to_s.gsub(/\s+/, "")
        faq_a = faq.answer.to_s.gsub(/\s+/, "")
        faq_q.include?(normalized[0, 10]) || faq_a.include?(normalized[0, 10])
      end
    end
  end
end
