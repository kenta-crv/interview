class Public::FollowUpTrackingController < ApplicationController
  skip_before_action :verify_authenticity_token

  TRANSPARENT_GIF = Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==").freeze

  def open
    delivery = FollowUpDelivery.find_by(tracking_token: params[:token])
    delivery&.mark_opened!

    send_data TRANSPARENT_GIF, type: "image/gif", disposition: "inline"
  end

  def click
    delivery = FollowUpDelivery.find_by(sales_click_token: params[:token]) ||
               FollowUpDelivery.find_by(contract_click_token: params[:token])

    unless delivery
      redirect_to root_path, alert: "無効なリンクです"
      return
    end

    if delivery.sales_click_token == params[:token]
      delivery.mark_sales_call_clicked!
      redirect_to destination_url(delivery.deal.follow_up_sales_url.presence || root_path)
    else
      delivery.mark_contract_clicked!
      redirect_to destination_url(delivery.deal.presentation_cta_url.presence || root_path)
    end
  end

  def unsubscribe
    user_progress = UserProgress.find_by(follow_up_unsubscribe_token: params[:token])

    unless user_progress
      render plain: "無効なURLです", status: :not_found
      return
    end

    DealFollowUp::UnsubscribeService.call(
      user_progress: user_progress,
      source: "email_link",
      request: request
    )

    render inline: unsubscribe_html, layout: false
  end

  private

  def destination_url(url)
    uri = URI.parse(url.to_s)
    uri.scheme.present? ? url : root_path
  rescue URI::InvalidURIError
    root_path
  end

  def unsubscribe_html
    <<~HTML
      <!DOCTYPE html>
      <html lang="ja">
      <head>
        <meta charset="UTF-8">
        <title>受け付け完了</title>
        <style>
          body { font-family: sans-serif; background: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .box { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); text-align: center; max-width: 420px; }
          h1 { margin-bottom: 12px; font-size: 1.4rem; }
          p { color: #64748b; line-height: 1.7; }
        </style>
      </head>
      <body>
        <div class="box">
          <h1>ご意向を受け付けました</h1>
          <p>興味がない・導入を見送る旨を記録しました。今後、この商談に関するフォローメールは送信されません。</p>
        </div>
      </body>
      </html>
    HTML
  end
end
