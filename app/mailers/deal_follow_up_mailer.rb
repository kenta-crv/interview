class DealFollowUpMailer < ApplicationMailer
  SMTP_FROM = "info@j-work.jp".freeze

  def follow_up(delivery)
    @delivery = delivery
    @renderer = DealFollowUp::BodyRenderer.new(delivery)
    @open_tracking_url = @renderer.open_tracking_url
    client = delivery.user_progress.deal.client
    reply_to_email = client&.email.presence || Admin.order(:id).pick(:email).presence || SMTP_FROM

    # From は SMTP 認証アカウントと一致させる（別アドレスだとリレー拒否・認証失敗の原因になる）
    mail(
      to: delivery.user.email,
      from: SMTP_FROM,
      reply_to: reply_to_email,
      subject: @renderer.subject
    )
  end
end
