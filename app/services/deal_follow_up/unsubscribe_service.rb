module DealFollowUp
  class UnsubscribeService
    def self.call(user_progress:, source: "email_link", request: nil)
      new(user_progress: user_progress, source: source, request: request).call
    end

    def initialize(user_progress:, source:, request:)
      @user_progress = user_progress
      @source = source
      @request = request
    end

    def call
      return if @user_progress.follow_up_unsubscribed?

      ActiveRecord::Base.transaction do
        @user_progress.update!(follow_up_unsubscribed_at: Time.current)
        @user_progress.follow_up_unsubscribes.create!(
          token: @user_progress.follow_up_unsubscribe_token,
          source: @source,
          ip_address: @request&.remote_ip,
          user_agent: @request&.user_agent
        )
        @user_progress.follow_up_deliveries.where(status: "scheduled").find_each(&:cancel!)
      end
    end
  end
end
