module DashboardHelper
  def sidebar_account_client
    if defined?(@target_client) && @target_client.present?
      @target_client
    elsif client_signed_in?
      current_client
    end
  end

  def sidebar_nav_deal
    return @deal if defined?(@deal) && @deal&.persisted?

    @sidebar_nav_deal ||= sidebar_account_client&.deals&.order(updated_at: :desc)&.first
  end

  def sidebar_leads_path
    deal = sidebar_nav_deal
    deal&.persisted? ? dashboard_deal_user_progresses_path(deal) : dashboard_index_path(anchor: "deals-hub")
  end

  def sidebar_dashboard_accessible?
    sidebar_account_client&.dashboard_accessible?
  end

  def sidebar_client_session?
    client_signed_in?
  end

  def sidebar_link_active?(key)
    case key
    when :dashboard
      %w[dashboard setup].include?(controller_name)
    when :deals
      controller_name == "deals"
    when :homepage_feature
      false
    when :leads
      controller_name == "user_progresses" && !@deal&.featured_on_homepage?
    when :company_logs
      controller_name == "user_progresses" && @deal&.featured_on_homepage?
    when :subscription
      controller_name == "subscriptions"
    when :account
      controller_name == "accounts"
    when :management
      controller_name == "management"
    else
      false
    end
  end

  def sidebar_link_class(key, *extras)
    classes = ["db-v2-sidebar__link", *extras]
    classes << "db-v2-sidebar__link--active" if sidebar_link_active?(key)
    classes.compact.join(" ")
  end

  def sidebar_plan_label
    sidebar_account_client&.current_plan_config&.dig(:name) || "—"
  end

  def sidebar_user_display_name
    client = sidebar_account_client
    client&.name.presence || client&.email.to_s.split("@").first.presence || "User"
  end

  def sidebar_avatar_initials(name)
    str = name.to_s.strip
    return "?" if str.blank?

    parts = str.split(/[\s@._-]+/).reject(&:blank?)
    first = parts.first.to_s
    if first.match?(/\A[\p{Han}\p{Hiragana}\p{Katakana}]/)
      first[0]
    else
      parts.first(2).map { |part| part[0] }.join.upcase
    end
  end

  def subscription_path_options
    if acting_as_admin? && defined?(@target_client) && @target_client.present?
      { client_id: @target_client.id }
    else
      {}
    end
  end

  def deal_language_label(deal)
    deal.language == "ja" ? t("meetia.dashboard.language.ja") : t("meetia.dashboard.language.en")
  end

  def subscription_can_cancel?(client)
    return false if acting_as_admin?

    client.subscription_cancellable?
  end

  def funnel_pie_gradient(segments)
    return "var(--db-surface-soft, #e2e8f0)" if segments.blank?

    stops = segments.map { |s| "#{s[:color]} #{s[:start_pct]}% #{s[:end_pct]}%" }
    "conic-gradient(#{stops.join(', ')})"
  end

  def funnel_pie_center_value(analytics)
    return analytics[:completion_rate] ? "#{analytics[:completion_rate]}%" : "—" if analytics[:sessions_started].to_i.positive?

    analytics[:page_views].to_i
  end

  def funnel_pie_center_label(analytics)
    analytics[:sessions_started].to_i.positive? ? t("meetia.dashboard.home.funnel_center_completion") : t("meetia.dashboard.home.funnel_center_access")
  end

  def visitor_journey_tracker(summary, compact: false)
    summary ||= {}
    current_index = summary[:step_index].to_i
    current_key = summary[:step].presence || "registered"
    css = ["db-v2-journey"]
    css << "db-v2-journey--compact" if compact

    content_tag(:ol, class: css.join(" "), "aria-label": t("meetia.dashboard.journey.label")) do
      safe_join(
        UserProgress::JOURNEY_STEPS.each_with_index.map do |key, index|
          classes = ["db-v2-journey__step"]
          classes << "is-reached" if index <= current_index
          classes << "is-current" if key == current_key
          content_tag(:li, class: classes.join(" ")) do
            content_tag(:span, "", class: "db-v2-journey__dot", "aria-hidden": "true") +
              content_tag(:span, t("meetia.dashboard.journey.steps.#{key}"), class: "db-v2-journey__label")
          end
        end
      )
    end
  end

  def visitor_journey_step_label(summary)
    key = summary.is_a?(Hash) ? summary[:step] : summary
    t("meetia.dashboard.journey.steps.#{key.presence || 'registered'}")
  end

  # 滞在時間（ms）。ja: 3分37秒 / en: 3 min 37 sec
  def format_duration_ms(ms)
    return t("meetia.dashboard.common.duration_empty") if ms.blank?

    seconds = (ms.to_f / 1000.0).round
    return t("meetia.dashboard.common.duration_seconds", seconds: seconds) if seconds < 60

    minutes = seconds / 60
    remain = seconds % 60
    if remain.zero?
      t("meetia.dashboard.common.duration_minutes", minutes: minutes)
    else
      t("meetia.dashboard.common.duration_minutes_seconds", minutes: minutes, seconds: remain)
    end
  end

  def session_leave_detail(metadata)
    meta = metadata.is_a?(Hash) ? metadata : {}
    page = meta["current_page_number"].presence || meta[:current_page_number].presence || "—"
    duration = format_duration_ms(meta["duration_ms"] || meta[:duration_ms])
    t("meetia.dashboard.deals.session_leave", page: page, duration: duration)
  end

  def client_setup_progress(deals = @deals)
    return if acting_as_admin?
    return unless client_signed_in?

    list = Array(deals)
    return if list.any?(&:playback_ready?)

    focus = list.first
    has_deal = focus.present?
    has_upload = has_deal && setup_deal_has_proposal?(focus)
    upload_done = has_upload && !focus.processing? && !focus.failed?
    current_step =
      if !has_deal
        :create
      elsif !upload_done
        :upload
      else
        :publish
      end

    {
      current_step: current_step,
      focus_deal: focus,
      steps: [
        { key: :create, done: has_deal },
        { key: :upload, done: upload_done },
        { key: :publish, done: false }
      ],
      cta_path: (current_step == :create || focus.blank?) ? new_dashboard_deal_path : dashboard_deal_path(focus),
      cta_key: "meetia.dashboard.setup.cta_#{current_step}"
    }
  end

  def deal_next_setup_action(deal)
    return if deal.blank?
    return unless can_manage_deal?(deal)
    return if deal.processing?
    return if deal.playback_ready?

    if setup_deal_has_proposal?(deal) && deal.deal_pages.any?
      {
        kind: :publish,
        href: "#content-edit",
        title_key: "meetia.dashboard.deals.next_publish_title",
        lead_key: "meetia.dashboard.deals.next_publish_lead",
        cta_key: "meetia.dashboard.deals.next_publish_cta"
      }
    else
      {
        kind: :upload,
        href: "#documents-upload-form",
        title_key: "meetia.dashboard.deals.next_upload_title",
        lead_key: "meetia.dashboard.deals.next_upload_lead",
        cta_key: "meetia.dashboard.deals.next_upload_cta"
      }
    end
  end

  def setup_deal_has_proposal?(deal)
    deal.deal_documents.any? { |doc| !doc.supplement? }
  end
end
