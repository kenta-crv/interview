class StripePlanValidator
  class ConfigurationError < StandardError; end

  class << self
    def purchasable_plan_types
      Subscription.purchasable_plans.keys
    end

    def validate!(plan_type = nil)
      errors = collect_errors(plan_type)
      return true if errors.empty?

      raise ConfigurationError, errors.join("\n")
    end

    def collect_errors(plan_type = nil)
      plan_types = plan_type.present? ? [plan_type.to_sym] : purchasable_plan_types
      errors = []

      plan_types.each do |key|
        config = Subscription.plan_config(key)
        env_key = config[:stripe_price_env]
        price_id = ENV[env_key]

        if price_id.blank?
          errors << "#{env_key} が未設定です（#{config[:name]} ¥#{config[:price]}/月）"
          next
        end

        stripe_price = Stripe::Price.retrieve(price_id)
        expected = config[:price]
        actual = stripe_price.unit_amount.to_i

        if actual != expected
          errors << "#{env_key} の金額が不一致: Stripe=¥#{actual} / カタログ=¥#{expected}（#{config[:name]}）"
        end

        if stripe_price.recurring&.interval != "month"
          errors << "#{env_key} は月額サブスクリプションではありません"
        end
      rescue Stripe::StripeError => e
        errors << "#{env_key} の取得に失敗: #{e.message}"
      end

      errors
    end

    def report
      lines = ["Meetia Stripe プラン整合性チェック", ""]

      purchasable_plan_types.each do |key|
        config = Subscription.plan_config(key)
        env_key = config[:stripe_price_env]
        price_id = ENV[env_key]
        catalog_amount = config[:price]

        if price_id.blank?
          lines << "[MISSING] #{key}: #{env_key} 未設定（期待 ¥#{catalog_amount}/月）"
          next
        end

        begin
          stripe_price = Stripe::Price.retrieve(price_id)
          actual = stripe_price.unit_amount.to_i
          status = actual == catalog_amount ? "OK" : "MISMATCH"
          lines << "[#{status}] #{key}: #{price_id} => Stripe ¥#{actual} / カタログ ¥#{catalog_amount}"
        rescue Stripe::StripeError => e
          lines << "[ERROR] #{key}: #{price_id} => #{e.message}"
        end
      end

      lines.join("\n")
    end

    def plan_type_for_price_id(price_id)
      return nil if price_id.blank?

      purchasable_plan_types.find do |key|
        ENV[Subscription.plan_config(key)[:stripe_price_env]] == price_id
      end&.to_s
    end
  end
end
