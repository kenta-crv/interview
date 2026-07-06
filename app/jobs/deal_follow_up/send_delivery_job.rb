module DealFollowUp
  class SendDeliveryJob < ApplicationJob
    queue_as :default

    def perform(delivery_id)
      delivery = FollowUpDelivery.find_by(id: delivery_id)
      return unless delivery

      SendDeliveryService.call(delivery)
    end
  end
end
