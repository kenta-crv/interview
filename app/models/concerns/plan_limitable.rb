module PlanLimitable
  extend ActiveSupport::Concern

  def current_plan_config
    Subscription.plan_config(subscription_plan.presence || :trial) || Subscription.plan_config(:trial)
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

  def prospect_follow_up_enabled?
    current_plan_config[:prospect_follow_up] == true
  end

  def click_analytics_enabled?
    current_plan_config[:click_analytics] == true
  end

  def faq_required_for_publish?
    !on_trial?
  end

  def show_knowledge_coverage?
    !on_trial?
  end

  def gap_analysis_suggest_only?
    on_trial?
  end

  def gap_analysis_question_limit
    on_trial? ? 3 : 8
  end

  def stress_test_question_limit
    on_trial? ? 3 : 8
  end

  def knowledge_tools_full?
    !on_trial?
  end

  def knowledge_section_optional?
    on_trial?
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
