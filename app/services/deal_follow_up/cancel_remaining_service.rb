module DealFollowUp
  class CancelRemainingService
    def self.call(user_progress:, source: "cta_click")
      new(user_progress: user_progress, source: source).call
    end

    def initialize(user_progress:, source:)
      @user_progress = user_progress
      @source = source
    end

    def call
      cancelled = 0
      ActiveRecord::Base.transaction do
        @user_progress.follow_up_deliveries.where(status: "scheduled").find_each do |delivery|
          delivery.cancel!
          cancelled += 1
        end
      end
      cancelled
    end
  end
end
