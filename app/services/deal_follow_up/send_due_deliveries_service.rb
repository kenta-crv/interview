module DealFollowUp
  class SendDueDeliveriesService
    def self.call
      new.call
    end

    def call
      FollowUpDelivery.pending_send.find_each do |delivery|
        SendDeliveryService.call(delivery)
      rescue StandardError => e
        Rails.logger.error("[DealFollowUp] send due failed delivery_id=#{delivery.id}: #{e.class}: #{e.message}")
      end
    end
  end
end
