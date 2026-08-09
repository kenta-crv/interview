class Subscription < ApplicationRecord
  belongs_to :client

  enum plan_type: { trial: "trial", starter: "starter", standard: "standard", business: "business", enterprise: "enterprise" }
  enum status: { active: "active", cancelled: "cancelled", expired: "expired" }

  validates :plan_type, presence: true
  validates :status, presence: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  TRIAL_DAYS = 14
  STANDARD_INTRO_PERCENT_OFF = 15
  STANDARD_INTRO_MONTHS = 3

  # プラン定義の唯一のソース（LP・プラン選択・制限・Stripe すべてここから参照）
  # price: JPY表示額 / prices: 通貨別表示額（usdはドル単位）
  PLAN_CATALOG = {
    trial: {
      name: "トライアル",
      name_en: "Trial",
      price: 0,
      prices: { jpy: 0, usd: 0 },
      deal_limit: 1,
      monthly_session_limit: 5,
      service_limit: 1,
      click_analytics: true,
      prospect_follow_up: false,
      prospect_follow_up_soon: false,
      description: "#{TRIAL_DAYS}日間。カード不要。終了後はスタンダードへ誘導",
      description_en: "#{TRIAL_DAYS} days, no card. Then guided to Standard",
      purchasable: false,
      public_on_lp: true,
      featured: false,
      stripe_price_env: nil,
      post_trial_plan: :standard,
      lp_cta: "無料で試す",
      lp_cta_en: "Try free"
    },
    starter: {
      name: "スターター",
      name_en: "Starter",
      price: 29_800,
      prices: { jpy: 29_800, usd: 199 },
      deal_limit: 15,
      monthly_session_limit: nil,
      service_limit: 1,
      click_analytics: true,
      prospect_follow_up: false,
      prospect_follow_up_soon: false,
      description: "（新規販売停止）",
      description_en: "(Not available for new purchases)",
      purchasable: false,
      public_on_lp: false,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_STARTER",
      stripe_price_envs: {
        jpy: "STRIPE_PRICE_STARTER",
        usd: "STRIPE_PRICE_STARTER_USD",
      }
    },
    standard: {
      name: "スタンダード",
      name_en: "Standard",
      price: 59_800,
      prices: { jpy: 59_800, usd: 399 },
      deal_limit: 50,
      monthly_session_limit: nil,
      service_limit: 3,
      click_analytics: true,
      prospect_follow_up: false,
      prospect_follow_up_soon: false,
      description: "成長中のチーム向け。商談50件・資料提示URL 3つ・クリック分析付き。",
      description_en: "For growing teams. 50 deals, 3 presentation URLs, and click analytics.",
      purchasable: true,
      public_on_lp: true,
      popular: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_STANDARD",
      stripe_price_envs: {
        jpy: "STRIPE_PRICE_STANDARD",
        usd: "STRIPE_PRICE_STANDARD_USD",
      },
      intro_coupon_env: "STRIPE_COUPON_STANDARD_INTRO",
      lp_cta_en: "Choose Standard"
    },
    business: {
      name: "Business",
      name_en: "Business",
      price: 98_000,
      prices: { jpy: 98_000, usd: 699 },
      deal_limit: 100,
      monthly_session_limit: nil,
      service_limit: 7,
      click_analytics: true,
      prospect_follow_up: true,
      prospect_follow_up_soon: false,
      description: "本格運用向け。商談100件・サービス7・クリック分析・見込み客追い付き。",
      description_en: "For full-scale ops. 100 deals, 7 services, click analytics, and prospect follow-up.",
      purchasable: true,
      public_on_lp: true,
      featured: true,
      stripe_price_env: "STRIPE_PRICE_BUSINESS",
      stripe_price_envs: {
        jpy: "STRIPE_PRICE_BUSINESS",
        usd: "STRIPE_PRICE_BUSINESS_USD",
      },
      lp_cta_en: "Choose Business"
    },
    enterprise: {
      name: "エンタープライズ",
      name_en: "Enterprise",
      price: 198_000,
      prices: { jpy: 198_000, usd: 1_299 },
      deal_limit: nil,
      monthly_session_limit: nil,
      service_limit: 10,
      click_analytics: true,
      prospect_follow_up: true,
      prospect_follow_up_soon: true,
      description: "大規模運用向け。商談無制限・資料提示URL 10・見込み追客（準備中）。",
      description_en: "For large-scale ops. Unlimited deals, 10 presentation URLs, prospect follow-up (coming soon).",
      purchasable: true,
      public_on_lp: true,
      featured: false,
      stripe_price_env: "STRIPE_PRICE_ENTERPRISE",
      stripe_price_envs: {
        jpy: "STRIPE_PRICE_ENTERPRISE",
        usd: "STRIPE_PRICE_ENTERPRISE_USD",
      },
      lp_cta_en: "Choose Enterprise"
    }
  }.freeze

  LP_COMPARISON_FEATURES = [
    { key: :deal_limit, label: "商談数", label_en: "Deals" },
    { key: :service_limit, label: "サービス数（資料提示URL）", label_en: "Services (presentation URLs)" },
    { key: :click_analytics, label: "クリック履歴分析", label_en: "Click analytics" },
    { key: :prospect_follow_up, label: "見込みの追い", label_en: "Prospect follow-up" }
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

    def lp_display_plans
      PLAN_CATALOG.select { |_key, config| config[:public_on_lp] }.to_a
    end

    def purchasable_plans
      PLAN_CATALOG.select { |_key, config| config[:purchasable] }
    end

    def price_for(plan_type, currency: :jpy)
      config = plan_config(plan_type)
      return 0 unless config

      currency = currency.to_sym
      config.dig(:prices, currency) || (currency == :jpy ? config[:price] : nil) || config[:price] || 0
    end

    def intro_price_for(plan_type, currency: :jpy)
      base = price_for(plan_type, currency: currency).to_f
      (base * (100 - STANDARD_INTRO_PERCENT_OFF) / 100.0).round
    end

    def stripe_price_id_for(plan_type, currency: :jpy)
      config = plan_config(plan_type)
      return nil unless config

      env_key = config.dig(:stripe_price_envs, currency.to_sym) || config[:stripe_price_env]
      return nil if env_key.blank?

      ENV[env_key].presence
    end

    def intro_coupon_id_for(plan_type)
      env_key = plan_config(plan_type)&.dig(:intro_coupon_env)
      return nil if env_key.blank?

      ENV[env_key].presence
    end

    def format_limit(value)
      value.nil? ? "無制限" : value.to_s
    end

    def format_price(plan_type, currency: :jpy)
      amount = price_for(plan_type, currency: currency)
      return BillingCurrency.symbol(currency) + "0" if amount.to_i.zero?

      case currency.to_sym
      when :usd
        "#{BillingCurrency.symbol(currency)}#{amount}"
      else
        "¥#{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      end
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

  def monthly_session_limit
    plan_config&.dig(:monthly_session_limit)
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

  # 自動課金せず期限切れにする（閲覧継続・有料は手動）
  def expire_trial_without_charge!
    return unless trial?
    return if trial_ends_at.blank?
    return if trial_ends_at > Time.current
    return if status != "active"

    update!(status: :expired)
    client.update_columns(subscription_status: "expired") if client.has_attribute?(:subscription_status)
  end

  def expire_trial_and_upgrade!
    expire_trial_without_charge!
  end
end
