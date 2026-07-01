class Dashboard::BaseController < ApplicationController
  layout "dashboard"

  before_action :authenticate_client!
  before_action :set_recent_deal_for_sidebar

  private

  def set_recent_deal_for_sidebar
    return if @deal.present?

    @deal = current_client.deals.order(updated_at: :desc).first
  end
end
