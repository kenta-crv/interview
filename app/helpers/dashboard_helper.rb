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

  def sidebar_show_deal_context?
    deal = sidebar_nav_deal
    return false unless deal&.persisted?

    deal_context_controller = controller_name == "user_progresses" ||
      (controller_name == "deals" && %w[show edit update].include?(action_name))

    (defined?(@deal) && @deal&.persisted?) || deal_context_controller
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
      controller_name == "dashboard"
    when :deals
      controller_name == "deals" && %w[index new create].include?(action_name)
    when :leads
      controller_name == "user_progresses"
    when :deal_studio
      controller_name == "deals" && %w[show edit update].include?(action_name)
    when :subscription
      controller_name == "subscriptions"
    when :account
      controller_name == "accounts"
    when :management
      controller_name == "management"
    when :admin_interview_results
      controller_path == "admin/interview_results"
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

  def subscription_path_options
    if admin_signed_in? && defined?(@target_client) && @target_client.present?
      { client_id: @target_client.id }
    else
      {}
    end
  end

  def deal_language_label(deal)
    deal.language == "ja" ? "日本語" : "English"
  end

  def subscription_can_cancel?(client)
    return false if admin_signed_in?

    client.subscription_cancellable?
  end
end
