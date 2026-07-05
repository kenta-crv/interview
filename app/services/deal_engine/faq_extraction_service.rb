require "pdf-reader"

module DealEngine
  class FaqExtractionService
    def initialize(deal_document)
      @document = deal_document
      @deal = deal_document.deal
    end

    def extract!
      return { created: 0, error: "not_pdf" } unless @document.file.attached?
      return { created: 0, error: "not_supplement" } unless @document.supplement?

      text = extract_pdf_text
      return { created: 0, error: "empty_text" } if text.blank?

      pairs = fetch_qa_pairs(text)
      created = persist_pairs(pairs)
      { created: created, total: pairs.size }
    end

    private

    def extract_pdf_text
      tempfile = Tempfile.new(["supplement", ".pdf"], binmode: true)
      tempfile.write(@document.file.download)
      tempfile.flush

      reader = PDF::Reader.new(tempfile.path)
      reader.pages.map(&:text).join("\n\n").strip
    ensure
      tempfile&.close!
    end

    def fetch_qa_pairs(text)
      api_key = ENV["OPENAI_API_KEY"]
      return heuristic_pairs(text) if api_key.blank?

      prompt = if @deal.language == "ja"
        <<~PROMPT
          以下の補足資料テキストから、Buyer向けFAQ（質問と回答のペア）を抽出してください。
          明確なQ&Aがなければ、内容から推測して最大10件作成してください。
          JSON配列のみ: [{"category":"pricing|implementation|security|comparison|support|contract|other","question":"...","answer":"..."}]

          【資料テキスト】
          #{text.truncate(8000)}
        PROMPT
      else
        <<~PROMPT
          Extract FAQ Q&A pairs from this supplement document text. Max 10 items.
          JSON array only: [{"category":"...","question":"...","answer":"..."}]

          #{text.truncate(8000)}
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
        max_tokens: 2000,
        temperature: 0.3
      }.to_json

      response = http.request(request)
      body = JSON.parse(response.body)
      content = body.dig("choices", 0, "message", "content").to_s
      json = content[/\[[\s\S]*\]/]
      return heuristic_pairs(text) if json.blank?

      JSON.parse(json).filter_map { |item| normalize_pair(item) }
    rescue => e
      Rails.logger.error("FaqExtractionService AI error: #{e.message}")
      heuristic_pairs(text)
    end

    def heuristic_pairs(text)
      chunks = text.split(/\n{2,}/).map(&:strip).reject(&:blank?).first(5)
      chunks.map.with_index do |chunk, index|
        {
          category: "other",
          question: "補足資料のポイント#{index + 1}を教えてください",
          answer: chunk.truncate(500)
        }
      end
    end

    def normalize_pair(item)
      return nil unless item.is_a?(Hash)

      category = item["category"].to_s
      category = "other" unless DealFaq::CATEGORIES.key?(category)
      question = item["question"].to_s.strip
      answer = item["answer"].to_s.strip
      return nil if question.blank? || answer.blank?

      { category: category, question: question, answer: answer }
    end

    def persist_pairs(pairs)
      created = 0
      base_position = @deal.deal_faqs.maximum(:position).to_i + 1

      pairs.each_with_index do |pair, index|
        next if @deal.deal_faqs.exists?(["question = ?", pair[:question]])

        @deal.deal_faqs.create!(
          question: pair[:question],
          answer: pair[:answer],
          category: pair[:category],
          source: "supplement_pdf",
          status: "approved",
          position: base_position + index
        )
        created += 1
      end

      created
    end
  end
end
