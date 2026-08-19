class Dashboard::DashboardController < Dashboard::BaseController
  def index
    if acting_as_admin?
      @deals = Deal.includes(:deal_documents, :deal_summary, :user_progresses)
                   .order(updated_at: :desc)
      @display_name = t("meetia.dashboard.home.admin_name")
      deal_ids = Deal.pluck(:id)
    else
      @deals = current_client.deals
                             .includes(:deal_documents, :deal_summary, :user_progresses)
                             .order(updated_at: :desc)
      @display_name = current_client.name.presence || current_client.email
      deal_ids = current_client.deals.pluck(:id)
    end

    @recent_deals = @deals.limit(5)
    @analytics = DealEngine::AnalyticsSummaryService.call(deal_ids: deal_ids)

    scope = acting_as_admin? ? UserProgress.joins(:deal) : UserProgress.joins(:deal).where(deals: { client_id: current_client.id })
    @recent_leads = scope.includes(:user, :deal).order(updated_at: :desc).limit(5)

    render "dashboard/index"
  end
end
