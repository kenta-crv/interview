module DealEngine
  class FaqTemplateService
    TEMPLATE_QUESTIONS_JA = [
      { category: "pricing", question: "料金プランや費用の内訳を教えてください" },
      { category: "implementation", question: "導入までの期間と必要な体制を教えてください" },
      { category: "support", question: "導入後のサポート体制を教えてください" }
    ].freeze

    TEMPLATE_QUESTIONS_EN = [
      { category: "pricing", question: "Can you walk me through your pricing plans and cost breakdown?" },
      { category: "implementation", question: "What is the implementation timeline and what team do we need?" },
      { category: "support", question: "What support do you provide after go-live?" }
    ].freeze

    def initialize(deal)
      @deal = deal
    end

    def seed_if_empty!
      return if @deal.deal_faqs.exists?

      template_questions.each_with_index do |item, index|
        @deal.deal_faqs.create!(
          question: item[:question],
          answer: nil,
          category: item[:category],
          source: "template",
          status: "pending",
          position: index
        )
      end
    end

    private

    def template_questions
      japanese? ? TEMPLATE_QUESTIONS_JA : TEMPLATE_QUESTIONS_EN
    end

    def japanese?
      @deal.language.to_s == "ja"
    end
  end
end
