class Dashboard::BaseController < ApplicationController
  layout "dashboard"
  before_action :authenticate_dashboard_user!
  before_action :set_recent_deal_for_sidebar

  helper_method :deal_owner

  private

  def authenticate_dashboard_user!
    return if client_signed_in? || admin_signed_in?

    redirect_to new_client_session_path, alert: "ログインが必要です。"
  end

  def authenticate_client_only!
    return if client_signed_in? || admin_signed_in?

    redirect_to dashboard_root_path, alert: "企業アカウントでのログインが必要です。"
  end

  def require_client_account!
    return if client_signed_in?

    redirect_to dashboard_deals_path, alert: "この操作は企業アカウントでログインしてください。"
  end

  def set_recent_deal_for_sidebar
    return if @deal&.persisted?
    return unless client_signed_in?

    @deal = current_client.deals.order(updated_at: :desc).first
  end

  def deal_owner
    if admin_signed_in? && defined?(@deal) && @deal.present?
      @deal.client
    elsif client_signed_in?
      current_client
    end
  end
end
