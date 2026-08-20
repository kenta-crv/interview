# frozen_string_literal: true

class SubscriptionMailer < ApplicationMailer
  PRODUCT = "Meetia"
  default from: "info@j-work.jp"

  def notification(event:, subscription:, previous_plan: nil)
    assign_common(event, subscription, previous_plan)

    mail(
      to: SubscriptionNotifier::ADMIN_EMAIL,
      subject: admin_subject
    )
  end

  def client_notification(event:, subscription:, previous_plan: nil)
    assign_common(event, subscription, previous_plan)

    mail(
      to: @client.email,
      subject: client_subject
    )
  end

  private

  def assign_common(event, subscription, previous_plan)
    @event = event.to_sym
    @subscription = subscription
    @client = subscription.client
    @previous_plan = previous_plan
    @previous_plan_name = plan_label(previous_plan)
    @client_name = [@client.try(:name), @client.try(:company)].find(&:present?) || "お客様"
    @dashboard_url = dashboard_index_url(**mailer_url_options)
    @event_label = event_label
    @headline = event_headline
    @lead = event_lead
    @status_label = status_label
    @occurred_at = Time.current.strftime("%Y年%m月%d日 %H:%M")
    @trial_ends_label = @subscription.trial_ends_at&.strftime("%Y年%m月%d日 %H:%M")
  end

  def event_label
    case @event
    when :registered
      @subscription.trial? ? "トライアル申し込み" : "プラン登録"
    when :changed
      "プラン変更"
    when :cancelled
      "解約"
    else
      "契約更新"
    end
  end

  def event_headline
    case @event
    when :registered
      @subscription.trial? ? "トライアルが開始されました" : "プラン登録が完了しました"
    when :changed
      "プラン変更が完了しました"
    when :cancelled
      "解約を受け付けました"
    else
      "ご契約内容が更新されました"
    end
  end

  def event_lead
    case @event
    when :registered
      if @subscription.trial?
        "Meetia の無料トライアル申し込みです。内容を確認してください。"
      else
        "Meetia の有料プラン登録です。内容を確認してください。"
      end
    when :changed
      "契約プランが変更されました。"
    when :cancelled
      "解約手続きが完了しました。"
    else
      "契約内容に更新があります。"
    end
  end

  def status_label
    {
      "active" => "有効",
      "cancelled" => "解約済み",
      "expired" => "期限切れ"
    }[@subscription.status.to_s] || @subscription.status.to_s
  end

  def plan_label(plan_type)
    return "-" if plan_type.blank?

    Subscription::PLAN_NAMES[plan_type.to_sym] || plan_type.to_s
  end

  def mailer_url_options
    {
      host: ActionMailer::Base.default_url_options[:host].presence || ENV.fetch("APP_HOST", "meetia.pro"),
      protocol: ActionMailer::Base.default_url_options[:protocol].presence || "https"
    }
  end

  def admin_subject
    case @event
    when :registered
      @subscription.trial? ? "【#{PRODUCT}】トライアル申し込み" : "【#{PRODUCT}】サブスクリプション登録"
    when :changed
      "【#{PRODUCT}】サブスクリプション変更"
    when :cancelled
      "【#{PRODUCT}】サブスクリプション解約"
    else
      "【#{PRODUCT}】サブスクリプション通知"
    end
  end

  def client_subject
    case @event
    when :registered
      @subscription.trial? ? "【#{PRODUCT}】無料トライアル開始のお知らせ" : "【#{PRODUCT}】プラン登録完了のお知らせ"
    when :changed
      "【#{PRODUCT}】プラン変更完了のお知らせ"
    when :cancelled
      "【#{PRODUCT}】解約手続き完了のお知らせ"
    else
      "【#{PRODUCT}】ご契約に関するお知らせ"
    end
  end
end
