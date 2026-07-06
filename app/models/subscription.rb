class Subscription < ApplicationRecord
  belongs_to :client

  enum plan_type: { trial: "trial", starter: "starter", standard: "standard", business: "business", enterprise: "enterprise" }
  enum status: { active: "active", cancelled: "cancelled", expired: "expired" }

  validates :plan_type, presence: true
  validates :status, presence: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  TRIAL_DAYS = 10

  # プラン定義の唯一のソース（LP・プラン選択・制限・Stripe すべてここから参照）
  PLAN_CATALOG = {
    trial: {
      name: "トライアル",
      price: 0,
      deal_limit: 3,
      service_limit: 1,
      click_analytics: true,
      prospect_follow_up: false,
      prospect_follow_up_soon: false,
      description: "#{TRIAL_DAYS}日間。その後スタンダード移行",
      purchasable: false,
      public_on_lp: true,
      featured: false,
      stripe_price_env: nil,
      post_trial_plan: :standard,
      lp_cta: "無料で試す"
    },
    starter: {
      name: "スターター",
      price: 29_800,
      deal_limit: 15,
      service_limit: 1,
      click_analytics: true,
      prospect_follow_up: false,
      prospect_follow_up_soon: false,
      description: "小規模チーム向け。商談15件・資料提示URL 1つで始められます。",
      purchasable: true,
      public_on_lp: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_STARTER"
    },
    standard: {
      name: "スタンダード",
      price: 59_800,
      deal_limit: 50,
      service_limit: 3,
      click_analytics: true,
      prospect_follow_up: false,
      prospect_follow_up_soon: false,
      description: "成長中のチーム向け。商談50件・資料提示URL 3つ・クリック分析付き。",
      purchasable: true,
      public_on_lp: true,
      popular: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_STANDARD"
    },
    business: {
      name: "Business",
      price: 98_000,
      deal_limit: 100,
      service_limit: 7,
      click_analytics: true,
      prospect_follow_up: true,
      prospect_follow_up_soon: false,
      description: "本格運用向け。商談100件・サービス7・クリック分析・見込み客追い付き。",
      purchasable: true,
      public_on_lp: true,
      featured: true,
      stripe_price_env: "STRIPE_PRICE_BUSINESS"
    },
    enterprise: {
      name: "エンタープライズ",
      price: 198_000,
      deal_limit: nil,
      service_limit: 10,
      click_analytics: true,
      prospect_follow_up: true,
      prospect_follow_up_soon: true,
      description: "大規模運用向け。商談無制限・資料提示URL 10・見込み追客（準備中）。",
      purchasable: true,
      public_on_lp: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_ENTERPRISE"
    }
  }.freeze

  LP_COMPARISON_FEATURES = [
    { key: :deal_limit, label: "商談数" },
    { key: :service_limit, label: "サービス数（資料提示URL）" },
    { key: :click_analytics, label: "クリック履歴分析" },
    { key: :prospect_follow_up, label: "見込みの追い" }
  ].freeze

  class << self
    def plan_config(plan_type)
      return nil if plan_type.blank?

      PLAN_CATALOG[plan_type.to_sym]
    end

    def public_plans
      PLAN_CATALOG.select { |_key, config| config[:public_on_lp] }
    end

    def lp_plans
      public_plans
    end

    def purchasable_plans
      PLAN_CATALOG.select { |_key, config| config[:purchasable] }
    end

    def stripe_price_id_for(plan_type)
      env_key = plan_config(plan_type)&.dig(:stripe_price_env)
      return nil if env_key.blank?

      ENV[env_key].presence
    end

    def format_limit(value)
      value.nil? ? "無制限" : value.to_s
    end

    def format_feature_value(plan_type, feature_key)
      config = plan_config(plan_type)
      return "—" unless config

      case feature_key
      when :deal_limit, :service_limit
        format_limit(config[feature_key])
      when :click_analytics
        config[feature_key] ? "✔︎" : "✕"
      when :prospect_follow_up
        if config[:prospect_follow_up_soon]
          "近日公開"
        elsif config[:prospect_follow_up]
          "✔︎"
        else
          "✕"
        end
      end
    end
  end

  PLAN_NAMES = PLAN_CATALOG.transform_values { |c| c[:name] }.freeze
  PLAN_PRICES = PLAN_CATALOG.transform_values { |c| c[:price] }.freeze
  PLAN_DELIVERY_LIMITS = PLAN_CATALOG.transform_values { |c| c[:deal_limit] || Float::INFINITY }.freeze

  def plan_config
    self.class.plan_config(plan_type)
  end

  def plan_name
    plan_config&.dig(:name) || plan_type.to_s
  end

  def price
    plan_config&.dig(:price) || 0
  end

  def deal_limit
    plan_config&.dig(:deal_limit)
  end

  def service_limit
    plan_config&.dig(:service_limit)
  end

  def delivery_limit
    deal_limit || Float::INFINITY
  end

  def click_analytics?
    plan_config&.dig(:click_analytics) == true
  end

  def trial?
    plan_type == "trial"
  end

  def trial_active?
    trial? && trial_ends_at.present? && trial_ends_at > Time.current
  end

  def trial_expired?
    trial? && trial_ends_at.present? && trial_ends_at <= Time.current
  end

  def expire_trial_and_upgrade!
    return unless trial?
    return if trial_ends_at.blank?
    return if trial_ends_at > Time.current
    return if status != "active"

    upgrade_plan = plan_config&.dig(:post_trial_plan) || :standard

    transaction do
      update!(status: :expired)
      client.subscriptions.where(status: :active).update_all(status: :cancelled)
      client.subscriptions.create!(plan_type: upgrade_plan, status: :active)
      client.update!(subscription_plan: upgrade_plan.to_s, subscription_status: "active")
    end
  end
end
