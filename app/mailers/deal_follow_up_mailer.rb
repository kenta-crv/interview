class DealFollowUpMailer < ApplicationMailer
  def follow_up(delivery)
    @delivery = delivery
    @renderer = DealFollowUp::BodyRenderer.new(delivery)
    @open_tracking_url = @renderer.open_tracking_url
    client = delivery.user_progress.deal.client

    mail(
      to: delivery.user.email,
      from: client.email,
      reply_to: client.email,
      subject: @renderer.subject
    )
  end
end
