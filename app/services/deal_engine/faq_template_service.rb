module DealEngine
  class FaqTemplateService
    TEMPLATE_QUESTIONS = [
      { category: "pricing", question: "料金プランや費用の内訳を教えてください" },
      { category: "implementation", question: "導入までの期間と必要な体制を教えてください" },
      { category: "support", question: "導入後のサポート体制を教えてください" }
    ].freeze

    def initialize(deal)
      @deal = deal
    end

    def seed_if_empty!
      return if @deal.deal_faqs.exists?

      TEMPLATE_QUESTIONS.each_with_index do |item, index|
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
  end
end
