module PlanLimitable
  extend ActiveSupport::Concern

  def current_plan_config
    Subscription.plan_config(subscription_plan) || Subscription.plan_config(:trial)
  end

  def deal_limit
    current_plan_config[:deal_limit]
  end

  def service_limit
    current_plan_config[:service_limit]
  end

  def deals_count
    deals.count
  end

  def active_services_count
    situations.active.count
  end

  def can_create_deal?
    limit = deal_limit
    limit.nil? || deals_count < limit
  end

  def can_create_service?
    active_services_count < service_limit
  end

  def click_analytics_enabled?
    current_plan_config[:click_analytics] == true
  end

  def deal_limit_message
    limit = deal_limit
    return nil if limit.nil?

    "商談数の上限（#{limit}件）に達しています。プランをアップグレードしてください。"
  end

  def service_limit_message
    "サービス数（資料提示URL）の上限（#{service_limit}件）に達しています。プランをアップグレードしてください。"
  end
end
