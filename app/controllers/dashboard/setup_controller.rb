class Dashboard::SetupController < Dashboard::BaseController
  def show
    if acting_as_admin? || !current_client.first_setup_incomplete?
      redirect_to dashboard_index_path
      return
    end

    @deals = current_client.deals
                           .where(managed_by_admin: false)
                           .includes(:deal_documents)
                           .order(updated_at: :desc)
  end
end
