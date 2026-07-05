class ExtractSupplementFaqsJob < ApplicationJob
  queue_as :default

  def perform(deal_document_id)
    document = DealDocument.find(deal_document_id)
    DealEngine::FaqExtractionService.new(document).extract!
  end
end
