module DealEngine
  class FaqTemplateService
    TEMPLATE_QUESTIONS = [
      { category: "pricing", question: "料金プランや費用の内訳を教えてください" },
      { category: "implementation", question: "導入までの期間と必要な体制を教えてください" },
      { category: "support", question: "導入後のサポート体制を教えてください" }
    ].freeze

    GENERIC_ANSWER_JA = "詳細は担当者よりご案内いたします。商談資料の範囲でお答えできる場合は、その内容をご確認ください。".freeze
    GENERIC_ANSWER_EN = "Please contact our team for details. I will answer based on the proposal materials when possible.".freeze

    def initialize(deal)
      @deal = deal
    end

    def seed_if_empty!
      return if @deal.deal_faqs.exists?

      generic = @deal.language == "ja" ? GENERIC_ANSWER_JA : GENERIC_ANSWER_EN

      TEMPLATE_QUESTIONS.each_with_index do |item, index|
        @deal.deal_faqs.create!(
          question: item[:question],
          answer: generic,
          category: item[:category],
          source: "template",
          status: "approved",
          position: index
        )
      end
    end
  end
end
