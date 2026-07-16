class Dashboard::UserProgressesController < Dashboard::BaseController
  before_action :set_deal

  def index
    @user_progresses = @deal.user_progresses.includes(:user).order(created_at: :desc)
    @evaluations_by_user_id = @deal.deal_evaluations.index_by(&:user_id)
  end

  def show
    @user_progress = @deal.user_progresses.find(params[:id])
    @presentation_events = @deal.deal_presentation_events
                               .where(user_id: @user_progress.user_id)
                               .recent_first
                               .limit(100)
    @follow_up_deliveries = @user_progress.follow_up_deliveries.includes(:deal_follow_up_template).ordered
    @follow_up_unsubscribes = @user_progress.follow_up_unsubscribes.order(unsubscribed_at: :desc)
  end

  private

  def set_deal
    @deal = if admin_signed_in?
              Deal.find(params[:deal_id])
            else
              current_client.deals.find(params[:deal_id])
            end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_deals_path, alert: "商談が見つかりません。"
  end
end
