class TopsController < ApplicationController
  layout "lp"

  before_action :set_lp_nav, only: :index

  def index
  end

  def interview
    current_client&.check_and_upgrade_expired_trial
    @situations = Situation.where(archived: false).order(:title)
    render layout: "application"
  end

  private

  def set_lp_nav
    @lp_page = "index"
  end
end
