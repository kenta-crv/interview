class PlansController < ApplicationController
  layout "dashboard_focus"

  before_action :authenticate_client!

  def index
    @is_new_account = current_client.new_account?

    @subscription = current_client.subscriptions
                                 .where(status: :active)
                                 .order(created_at: :desc)
                                 .first

    if @subscription.nil?
      @subscription = current_client.subscriptions
                                   .order(created_at: :desc)
                                   .first
    end

    @payments = current_client.payments
                              .order(created_at: :desc)
                              .limit(50)
  end

  def select
    plan_type = params[:plan_type]

    unless Subscription::PLAN_CATALOG.key?(plan_type.to_sym)
      redirect_to plans_path, alert: "無効なプランです。"
      return
    end

    if plan_type == "trial"
      unless current_client.new_account?
        redirect_to plans_path, alert: "無料トライアルは新規アカウントのみ利用できます。"
        return
      end

      redirect_to checkout_confirmation_path(plan_type: "trial")
      return
    end

    redirect_to checkout_confirmation_path(plan_type: plan_type)
  end
end
