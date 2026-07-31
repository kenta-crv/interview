class DealSalesCallMailer < ApplicationMailer
  default from: "info@j-work.jp"

  def request_notification(user_progress:, source: "presentation")
    @user_progress = user_progress
    @user = user_progress.user
    @deal = user_progress.deal
    @client = @deal.client
    @source = source
    @phase_label = DealSalesCall::NotifyClientService.phase_label(user_progress)
    @dashboard_url = dashboard_url_for(@deal, user_progress)
    recipient = @client&.email.presence || Admin.order(:id).pick(:email)

    mail(
      to: recipient,
      reply_to: @user.email.presence,
      subject: "【Meetia】担当者商談の希望：#{@user.company.presence || @user.name.presence || '見込み客'}様"
    )
  end

  def session_completed(user_progress:, rating: nil, feedback: nil)
    @user_progress = user_progress
    @user = user_progress.user
    @deal = user_progress.deal
    @client = @deal.client
    @rating = rating
    @feedback = feedback.to_s
    @phase_label = DealSalesCall::NotifyClientService.phase_label(user_progress)
    @dashboard_url = dashboard_url_for(@deal, user_progress)
    recipient = @client&.email.presence || Admin.order(:id).pick(:email)

    mail(
      to: recipient,
      reply_to: @user.email.presence,
      subject: "【Meetia】AI商談が終了しました：#{@user.company.presence || @user.name.presence || '見込み客'}様"
    )
  end

  private

  def dashboard_url_for(deal, user_progress)
    host = ActionMailer::Base.default_url_options[:host].presence ||
           ENV.fetch("APP_HOST", "localhost:3000")
    Rails.application.routes.url_helpers.dashboard_deal_user_progress_url(
      deal,
      user_progress,
      host: host,
      protocol: (Rails.env.development? ? "http" : "https")
    )
  rescue StandardError
    nil
  end
end
