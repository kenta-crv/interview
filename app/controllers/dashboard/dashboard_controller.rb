class Dashboard::DashboardController < ApplicationController
  before_action :authenticate_client!
  before_action :set_recent_deal_for_sidebar

  def index
    render "dashboard/index"
  end

  def setting
    render "dashboard/setting"
  end

  def management
    render "dashboard/management"
  end

  private

  # 共通サイドバーの動的リンクが全画面でクラッシュするのを防ぐための防衛コード
  def set_recent_deal_for_sidebar
    @deal = current_client.deals.order(updated_at: :desc).first
  end
end