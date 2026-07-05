class AnalyzeDealKnowledgeGapsJob < ApplicationJob
  queue_as :default

  def perform(deal_id)
    deal = Deal.includes(:client, :deal_summary).find(deal_id)
    client = deal.client

    DealEngine::FaqTemplateService.new(deal).seed_if_empty! if client.on_trial?

    DealEngine::FaqGapAnalysisService.new(deal, client: client).analyze!
  end
end
