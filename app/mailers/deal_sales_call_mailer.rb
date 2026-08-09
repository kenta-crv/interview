class DealSalesCallMailer < ApplicationMailer
  default from: "info@j-work.jp"

  def request_notification(user_progress:, source: "presentation")
    @user_progress = user_progress
    @user = user_progress.user
    @deal = user_progress.deal
    @client = @deal.client
    @source = source.to_s
    @intro = request_notification_intro(@source)
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
    @summary_lines = user_progress.session_summary_lines
    summary = user_progress.session_summary_hash
    @interest_topics = Array(summary["topics"]).map(&:presence).compact.join("、")
    @grade_label = grade_label_for(user_progress)
    @dashboard_url = dashboard_url_for(@deal, user_progress)
    recipient = @client&.email.presence || Admin.order(:id).pick(:email)

    mail(
      to: recipient,
      reply_to: @user.email.presence,
      subject: "【Meetia】AI商談が終了しました：#{@user.company.presence || @user.name.presence || '見込み客'}様"
    )
  end

  private

  def request_notification_intro(source)
    case source.to_s
    when "follow_up_sales_click"
      "フォローメールから「担当者に相談する」が押されました。"
    when "follow_up_contract_click"
      "フォローメールから「契約について相談する」が押されました。"
    else
      "商談ルームから「担当者に繋ぐ」が押されました。"
    end
  end

  def grade_label_for(user_progress)
    grade = user_progress.prospect_grade.presence
    score = user_progress.prospect_score
    return "—" if grade.blank? && score.blank?
    return "#{grade}（#{score}点）" if grade.present? && score.present?
    return grade if grade.present?

    "#{score}点"
  end

  def dashboard_url_for(deal, user_progress)
    host = ActionMailer::Base.default_url_options[:host].presence ||
           ENV.fetch("APP_HOST", "meetia.pro")
    protocol = ActionMailer::Base.default_url_options[:protocol].presence ||
               (Rails.env.development? ? "http" : "https")

    Rails.application.routes.url_helpers.dashboard_deal_user_progress_url(
      deal,
      user_progress,
      host: host,
      protocol: protocol
    )
  rescue StandardError => e
    Rails.logger.warn("[DealSalesCallMailer] dashboard_url failed: #{e.class}: #{e.message}")
    fallback_dashboard_url(deal, user_progress, host, protocol)
  end

  def fallback_dashboard_url(deal, user_progress, host, protocol)
    return nil if deal.blank? || user_progress.blank?

    "#{protocol}://#{host}/dashboard/deals/#{deal.id}/user_progresses/#{user_progress.id}"
  end
end
