module DealEngine
  class FaqFromEventsService
    def initialize(deal, limit: 10)
      @deal = deal
      @limit = limit
    end

    def suggest!
      messages = collect_candidate_messages
      created = 0

      messages.first(@limit).each do |message|
        question = normalize_question(message)
        next if question.blank?
        next if duplicate_question?(question)

        @deal.deal_faqs.create!(
          question: question,
          category: infer_category(question),
          source: "session_log",
          status: "pending",
          position: next_position + created
        )
        created += 1
      end

      { created: created, scanned: messages.size }
    end

    private

    def collect_candidate_messages
      @deal.deal_presentation_events
        .where(event_type: "free_text_send")
        .where.not(message: [nil, ""])
        .order(occurred_at: :desc)
        .pluck(:message)
        .map { |m| m.to_s.strip }
        .reject { |m| m.length < 4 }
        .uniq
        .reject { |message| already_covered?(message) }
    end

    def normalize_question(message)
      text = message.to_s.strip
      return text if text.end_with?("?", "？")

      "#{text}？"
    end

    def duplicate_question?(question)
      @deal.deal_faqs.exists?(["question = ?", question])
    end

    def already_covered?(message)
      normalized = message.gsub(/\s+/, "")
      @deal.deal_faqs.where(status: "approved").any? do |faq|
        faq.question.to_s.gsub(/\s+/, "").include?(normalized[0, 12])
      end
    end

    def infer_category(question)
      case question
      when /料金|費用|価格|プラン|ROI/i then "pricing"
      when /導入|期間|体制|連携/i then "implementation"
      when /セキュリティ|データ|個人情報/i then "security"
      when /競合|比較|違い/i then "comparison"
      when /サポート|保守/i then "support"
      when /契約|解約|更新/i then "contract"
      else
        "other"
      end
    end

    def next_position
      @deal.deal_faqs.maximum(:position).to_i + 1
    end
  end
end
