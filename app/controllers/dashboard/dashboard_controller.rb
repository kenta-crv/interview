class Dashboard::DashboardController < Dashboard::BaseController
  def index
    render "dashboard/index"
  end

  def setting
    render "dashboard/setting"
  end

  def management
    render "dashboard/management"
  end
end