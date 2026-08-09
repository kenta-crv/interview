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
      handle_sales_click!(delivery)
    else
      handle_contract_click!(delivery)
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

  def handle_sales_click!(delivery)
    delivery.mark_sales_call_clicked!
    DealFollowUp::CancelRemainingService.call(
      user_progress: delivery.user_progress,
      source: "sales_click"
    )

    destination = delivery.deal.follow_up_sales_url.presence
    if destination.present?
      redirect_to destination_url(destination)
      return
    end

    notify_owner_for_email_cta!(delivery, source: "follow_up_sales_click")
    render inline: cta_received_html("担当者へのご相談を受け付けました"), layout: false
  end

  def handle_contract_click!(delivery)
    delivery.mark_contract_clicked!
    DealFollowUp::CancelRemainingService.call(
      user_progress: delivery.user_progress,
      source: "contract_click"
    )

    destination = delivery.deal.presentation_cta_url.presence
    if destination.present?
      redirect_to destination_url(destination)
      return
    end

    notify_owner_for_email_cta!(delivery, source: "follow_up_contract_click")
    render inline: cta_received_html("契約についてのご相談を受け付けました"), layout: false
  end

  def notify_owner_for_email_cta!(delivery, source:)
    DealSalesCall::NotifyClientService.call(
      user_progress: delivery.user_progress,
      source: source
    )
  rescue StandardError => e
    Rails.logger.warn("[FollowUpTracking] owner notify failed: #{e.class}: #{e.message}")
  end

  def destination_url(url)
    uri = URI.parse(url.to_s)
    uri.scheme.present? ? url : root_path
  rescue URI::InvalidURIError
    root_path
  end

  def cta_received_html(title)
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
          <h1>#{title}</h1>
          <p>担当者よりご連絡いたします。今後、この商談に関する自動フォローメールは送信されません。</p>
        </div>
      </body>
      </html>
    HTML
  end

  def unsubscribe_html
    <<~HTML
      <!DOCTYPE html>
      <html lang="ja">
      <head>
        <meta charset="UTF-8">
        <title>配信停止完了</title>
        <style>
          body { font-family: sans-serif; background: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .box { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); text-align: center; max-width: 420px; }
          h1 { margin-bottom: 12px; font-size: 1.4rem; }
          p { color: #64748b; line-height: 1.7; }
        </style>
      </head>
      <body>
        <div class="box">
          <h1>配信を停止しました</h1>
          <p>今後、この商談に関するフォローメールは送信されません。</p>
        </div>
      </body>
      </html>
    HTML
  end
end
