# app/jobs/process_deal_job.rb
class ProcessDealJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 30.seconds, attempts: 2 unless Rails.env.test?

  def perform(deal_id)
    deal = Deal.find(deal_id)
    DealEngine::DealPipelineService.new(deal).process!
  end
end
