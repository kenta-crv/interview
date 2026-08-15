module Dashboard
  class AccountsController < Dashboard::BaseController
    before_action :authenticate_client!, only: [:update]
    before_action :set_client, only: [:update]

    def show
      @client = current_client if client_signed_in?
    end

    def update
      @client.assign_attributes(account_params)
      if @client.save(context: :profile_update)
        redirect_to dashboard_account_path, notice: t("meetia.dashboard.flash.account_updated")
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_client
      @client = current_client
    end

    def account_params
      params.require(:client).permit(:company, :name, :tel, :address, :url, :email)
    end
  end
end
