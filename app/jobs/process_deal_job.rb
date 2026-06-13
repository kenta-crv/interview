# app/jobs/process_deal_job.rb
class ProcessDealJob < ApplicationJob
  queue_as :default

  # インラインモードでは時間指定リトライ（wait: 10.seconds）が使えないため削除、
  # または本番環境（Sidekiq等）のみ適用する場合は以下のように条件付きにします。
  if Rails.env.production?
    retry_on StandardError, wait: 10.seconds, attempts: 2
  end

  def perform(deal_id)
    deal = Deal.find(deal_id)

    # べき等性チェック
    return if deal.completed? || deal.processing?

    # 簡略化された処理: Claude APIを直接使用
    deal.process_with_claude!
  end
end