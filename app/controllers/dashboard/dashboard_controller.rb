class Dashboard::DashboardController < Dashboard::BaseController
  def index
    if admin_signed_in?
      @deals = Deal.includes(:deal_documents, :deal_summary, :user_progresses)
                   .order(updated_at: :desc)
      @display_name = "管理者"
    else
      @deals = current_client.deals
                             .includes(:deal_documents, :deal_summary, :user_progresses)
                             .order(updated_at: :desc)
      @display_name = current_client.name.presence || current_client.email
    end

    @recent_deals = @deals.limit(5)
    @deals_count = admin_signed_in? ? Deal.count : @deals.size
    @published_deals_count = admin_signed_in? ? Deal.where(playback_ready: true).count : current_client.deals.where(playback_ready: true).count
    @processing_deals_count = if admin_signed_in?
                                Deal.where(status: [:uploading, :processing, :transcribing, :summarizing]).count
                              else
                                current_client.deals.where(status: [:uploading, :processing, :transcribing, :summarizing]).count
                              end
    scope = admin_signed_in? ? UserProgress.joins(:deal) : UserProgress.joins(:deal).where(deals: { client_id: current_client.id })
    @leads_count = scope.count
    @recent_leads = scope.includes(:user, :deal).order(updated_at: :desc).limit(5)

    render "dashboard/index"
  end
end
