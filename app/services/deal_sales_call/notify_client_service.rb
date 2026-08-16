module DealSalesCall
  class NotifyClientService
    PHASE_LABELS = {
      "initial" => "meetia.deal.phase_options.initial",
      "information_gathering" => "meetia.deal.phase_options.information_gathering",
      "evaluation" => "meetia.deal.phase_options.evaluation",
      "decision" => "meetia.deal.phase_options.decision"
    }.freeze

    def self.call(user_progress:, source: "presentation", session_key: nil)
      new(user_progress: user_progress, source: source, session_key: session_key).call
    end

    def initialize(user_progress:, source:, session_key:)
      @user_progress = user_progress
      @deal = user_progress.deal
      @user = user_progress.user
      @source = source.to_s
      @session_key = session_key
    end

    def call
      recipient_email = notification_email
      raise ArgumentError, I18n.t("meetia.owner_mail.missing_email") if recipient_email.blank?

      # 担当者通知は遅延キューに乗せると Sidekiq 未起動時に届かないため同期送信する
      DealSalesCallMailer.request_notification(
        user_progress: @user_progress,
        source: @source
      ).deliver_now

      log_event!(recipient_email)
      DealFollowUp::CancelRemainingService.call(
        user_progress: @user_progress,
        source: "sales_call_request"
      )

      { ok: true }
    end

    def self.phase_label(user_progress)
      key = PHASE_LABELS[user_progress.consideration_phase.to_s]
      return I18n.t(key) if key.present?

      user_progress.consideration_phase.to_s.presence || "—"
    end

    private

    def notification_email
      @deal.client&.email.presence || Admin.order(:id).pick(:email).presence
    end

    def log_event!(recipient_email)
      return if @session_key.blank?

      @deal.deal_presentation_events.create!(
        user: @user,
        user_progress: @user_progress,
        session_key: @session_key,
        event_type: "exit_sales_call_click",
        label: I18n.t("meetia.deal.sales_call"),
        metadata: {
          source: @source,
          notified_email: recipient_email,
          delivery: "email"
        },
        occurred_at: Time.current
      )
    end
  end
end
