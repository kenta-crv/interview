class Dashboard::UserProgressesController < Dashboard::BaseController
  before_action :set_deal

  def index
    @user_progresses = @deal.user_progresses.includes(:user).order(created_at: :desc)
  end

  def show
    @user_progress = @deal.user_progresses.find(params[:id])
    @presentation_events = @deal.deal_presentation_events
                               .where(user_id: @user_progress.user_id)
                               .recent_first
                               .limit(100)
  end

  private

  def set_deal
    @deal = current_client.deals.find(params[:deal_id])
  end
end
