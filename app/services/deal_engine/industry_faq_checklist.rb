module DealEngine
  class IndustryFaqChecklist
    CHECKLISTS = {
      "general" => [
        { category: "pricing", question: "料金体系と支払い条件を教えてください" },
        { category: "implementation", question: "導入スケジュールの目安を教えてください" },
        { category: "support", question: "導入後のサポート内容を教えてください" }
      ],
      "saas" => [
        { category: "pricing", question: "プラン別の機能差とユーザー単価を教えてください" },
        { category: "security", question: "データ保管場所とアクセス制御について教えてください" },
        { category: "implementation", question: "既存SaaSとのAPI連携可否を教えてください" },
        { category: "contract", question: "SLAとダウンタイム時の対応を教えてください" }
      ],
      "hr" => [
        { category: "implementation", question: "入国後の生活サポートの具体的内容を教えてください" },
        { category: "pricing", question: "成功報酬や追加費用の有無を教えてください" },
        { category: "support", question: "離職・トラブル発生時の対応フローを教えてください" },
        { category: "contract", question: "返金・キャンセル条件を教えてください" }
      ],
      "consulting" => [
        { category: "implementation", question: "プロジェクト体制と稼働工数の見積もりを教えてください" },
        { category: "pricing", question: "成果物の範囲と追加請求の条件を教えてください" },
        { category: "comparison", question: "類似プロジェクトの実績と成果指標を教えてください" }
      ],
      "manufacturing" => [
        { category: "implementation", question: "工場・現場への導入プロセスを教えてください" },
        { category: "security", question: "品質管理・トレーサビリティの仕組みを教えてください" },
        { category: "support", question: "保守部品とメンテナンス周期を教えてください" }
      ]
    }.freeze

    class << self
      def items_for(deal)
        CHECKLISTS[deal.industry] || CHECKLISTS["general"]
      end

      def apply!(deal)
        created = 0
        base_position = deal.deal_faqs.maximum(:position).to_i + 1

        items_for(deal).each_with_index do |item, index|
          next if deal.deal_faqs.exists?(["question = ?", item[:question]])

          answer = existing_answer_for(deal, item[:question])
          deal.deal_faqs.create!(
            question: item[:question],
            category: item[:category],
            source: "checklist",
            status: answer.present? ? "approved" : "pending",
            answer: answer,
            position: base_position + index
          )
          created += 1
        end

        { created: created, total: items_for(deal).size }
      end

      def coverage(deal)
        items = items_for(deal)
        return { total: 0, answered: 0, percent: 100, missing: [] } if items.empty?

        missing = []
        answered = 0

        items.each do |item|
          faq = deal.deal_faqs.find_by(question: item[:question])
          if faq&.approved? && faq.answered?
            answered += 1
          else
            missing << item
          end
        end

        percent = ((answered.to_f / items.size) * 100).round
        { total: items.size, answered: answered, percent: percent, missing: missing }
      end

      private

      def covered_by_existing?(deal, question)
        existing_answer_for(deal, question).present?
      end

      def existing_answer_for(deal, question)
        normalized = question.gsub(/\s+/, "")
        match = deal.deal_faqs.for_conversation.find do |faq|
          faq.question.to_s.gsub(/\s+/, "").include?(normalized[0, 8])
        end
        match&.answer
      end
    end
  end
end
