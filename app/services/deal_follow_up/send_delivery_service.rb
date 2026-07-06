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

      DealFollowUpMailer.follow_up(@delivery).deliver_now
      @delivery.mark_sent!
    rescue StandardError => e
      @delivery.update!(status: "failed", error_message: e.message)
      raise
    end

    private

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
