module DealFollowUp
  class SendDeliveryService
    def self.call(delivery)
      new(delivery).call
    end

    def initialize(delivery)
      @delivery = delivery
    end

    def call
      @delivery = FollowUpDelivery.lock.find(@delivery.id)
      return if skip_send?

      ensure_session_analyzed!
      DealFollowUpMailer.follow_up(@delivery).deliver_now
      @delivery.mark_sent!
    rescue StandardError => e
      @delivery.update!(status: "failed", error_message: e.message)
      raise
    end

    private

    def ensure_session_analyzed!
      progress = @delivery.user_progress
      return if progress.session_analyzed_at.present?

      DealEngine::SessionAnalysisService.call(user_progress: progress)
    rescue StandardError => e
      Rails.logger.warn("Follow-up session analysis skipped: #{e.message}")
    end

    def skip_send?
      @delivery.sent_or_beyond? ||
        @delivery.status == "cancelled" ||
        @delivery.user_progress.follow_up_unsubscribed? ||
        !client.prospect_follow_up_enabled?
    end

    def client
      @delivery.user_progress.deal.client
    end
  end
end
