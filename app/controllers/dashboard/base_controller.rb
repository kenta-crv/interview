class Dashboard::BaseController < ApplicationController
  layout "dashboard"
  before_action :authenticate_dashboard_user!
  before_action :set_recent_deal_for_sidebar

  helper_method :deal_owner, :can_manage_deal?, :follow_up_feature_available?

  private

  def authenticate_dashboard_user!
    return if client_signed_in? || admin_signed_in?

    redirect_to new_client_session_path, alert: "ログインが必要です。"
  end

  # Client自身の商談、または Admin管理商談のみ操作可能
  def authenticate_deal_manager!
    return if client_signed_in? || admin_signed_in?

    redirect_to dashboard_root_path, alert: "ログインが必要です。"
  end

  def require_client_account!
    return if client_signed_in?

    redirect_to dashboard_deals_path, alert: "クライアント商談の新規作成は企業アカウントでログインしてください。Admin商談はAdminで作成できます。"
  end

  def authorize_deal_management!
    return if @deal && can_manage_deal?(@deal)

    target = @deal.present? ? dashboard_deal_path(@deal) : dashboard_deals_path
    redirect_to target, alert: deal_management_forbidden_message
  end

  def can_manage_deal?(deal)
    return false if deal.blank?

    if deal.managed_by_admin?
      admin_signed_in?
    else
      client_signed_in? && deal.client_id == current_client.id
    end
  end

  def deal_management_forbidden_message
    if admin_signed_in?
      "この商談はクライアント管理です。公開・編集は企業アカウントで行ってください。"
    else
      "この商談はAdmin管理です。公開・編集はAdminアカウントで行ってください。"
    end
  end

  def set_recent_deal_for_sidebar
    return if @deal&.persisted?
    return unless client_signed_in?

    @deal = current_client.deals.where(managed_by_admin: false).order(updated_at: :desc).first
  end

  def deal_owner
    if defined?(@deal) && @deal.present?
      return @deal.client if @deal.client.present?
      return AdminDealOwner.new if @deal.managed_by_admin?
    elsif client_signed_in?
      current_client
    end
  end

  # Admin はプランに関係なく追客設定・検証を行える
  def follow_up_feature_available?(owner = deal_owner)
    admin_signed_in? || owner&.prospect_follow_up_enabled?
  end
end
