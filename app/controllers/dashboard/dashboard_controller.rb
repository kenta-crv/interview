class Dashboard::DashboardController < Dashboard::BaseController
  def index
    render "dashboard/index"
  end
end