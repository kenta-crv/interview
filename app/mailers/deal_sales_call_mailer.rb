class DealSalesCallMailer < ApplicationMailer
  default from: "info@j-work.jp"

  def request_notification(user_progress:, source: "presentation")
    @user_progress = user_progress
    @user = user_progress.user
    @deal = user_progress.deal
    @client = @deal.client
    @source = source.to_s
    @dashboard_url = dashboard_url_for(@deal, user_progress)
    recipient = @client&.email.presence || Admin.order(:id).pick(:email)
    name = @user.company.presence || @user.name.presence || I18n.t("meetia.owner_mail.prospect_fallback")

    I18n.with_locale(owner_locale) do
      @intro = request_notification_intro(@source)
      @phase_label = DealSalesCall::NotifyClientService.phase_label(user_progress)
      mail(
        to: recipient,
        reply_to: @user.email.presence,
        subject: I18n.t("meetia.owner_mail.request_subject", name: name)
      )
    end
  end

  def session_completed(user_progress:, rating: nil, feedback: nil)
    @user_progress = user_progress
    @user = user_progress.user
    @deal = user_progress.deal
    @client = @deal.client
    @rating = rating
    @feedback = feedback.to_s
    @dashboard_url = dashboard_url_for(@deal, user_progress)
    recipient = @client&.email.presence || Admin.order(:id).pick(:email)
    name = @user.company.presence || @user.name.presence || I18n.t("meetia.owner_mail.prospect_fallback")

    I18n.with_locale(owner_locale) do
      @phase_label = DealSalesCall::NotifyClientService.phase_label(user_progress)
      @summary_lines = user_progress.session_summary_lines
      summary = user_progress.session_summary_hash
      @interest_topics = Array(summary["topics"]).map(&:presence).compact.join(I18n.locale.to_s == "en" ? ", " : "、")
      @grade_label = grade_label_for(user_progress)
      mail(
        to: recipient,
        reply_to: @user.email.presence,
        subject: I18n.t("meetia.owner_mail.completed_subject", name: name)
      )
    end
  end

  private

  def owner_locale
    loc = @client.respond_to?(:ui_locale) ? @client.ui_locale.to_s : "ja"
    Client::LOCALES.include?(loc) ? loc.to_sym : :ja
  end

  def request_notification_intro(source)
    case source.to_s
    when "follow_up_sales_click"
      I18n.t("meetia.owner_mail.intro_follow_sales")
    when "follow_up_contract_click"
      I18n.t("meetia.owner_mail.intro_follow_contract")
    else
      I18n.t("meetia.owner_mail.intro_room")
    end
  end

  def grade_label_for(user_progress)
    grade = user_progress.prospect_grade.presence
    score = user_progress.prospect_score
    return "—" if grade.blank? && score.blank?
    return I18n.t("meetia.owner_mail.grade_with_score", grade: grade, score: score) if grade.present? && score.present?
    return grade if grade.present?

    I18n.t("meetia.owner_mail.score_only", score: score)
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
