module DealSession
  class NotifyOwnerService
    def self.call(user_progress:, rating: nil, feedback: nil)
      new(user_progress: user_progress, rating: rating, feedback: feedback).call
    end

    def initialize(user_progress:, rating:, feedback:)
      @user_progress = user_progress
      @deal = user_progress.deal
      @user = user_progress.user
      @rating = rating
      @feedback = feedback
    end

    def call
      recipient_email = notification_email
      raise ArgumentError, "担当者メールが設定されていません" if recipient_email.blank?

      DealSalesCallMailer.session_completed(
        user_progress: @user_progress,
        rating: @rating,
        feedback: @feedback
      ).deliver_now

      { ok: true, notified_email: recipient_email }
    end

    private

    def notification_email
      @deal.client&.email.presence || Admin.order(:id).pick(:email).presence
    end
  end
end
