# app/controllers/client/user_progresses_controller.rb
class Client::UserProgressesController < ApplicationController
  before_action :authenticate_client!
  before_action :set_deal

  def index
    @user_progresses = @deal.user_progresses.includes(:user).order(created_at: :desc)
  end

  def show
    @user_progress = @deal.user_progresses.find(params[:id])
  end

  private

  def set_deal
    @deal = current_client.deals.find(params[:deal_id])
  end
end
