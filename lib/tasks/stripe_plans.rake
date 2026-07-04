namespace :stripe do
  desc "PLAN_CATALOG と Stripe Price ID の金額整合性を確認"
  task validate_plans: :environment do
    puts StripePlanValidator.report
    errors = StripePlanValidator.collect_errors
    if errors.any?
      puts "\n問題:"
      errors.each { |e| puts "  - #{e}" }
      puts "\n修正: Stripe Dashboard で新 Price を作成し .env を更新するか、"
      puts "      bundle exec rake stripe:create_catalog_prices を実行してください。"
      exit 1
    end
    puts "\nすべて一致しています。"
  end

  desc "PLAN_CATALOG に合わせた Stripe Price を新規作成し .env 用の行を出力"
  task create_catalog_prices: :environment do
    product = Stripe::Product.list(limit: 20).data.find { |p| p.name == "Meetia Subscription" }
    product ||= Stripe::Product.create(
      name: "Meetia Subscription",
      description: "Meetia AI商談 月額プラン"
    )

    puts "# .env に追記・更新してください"
    Subscription.purchasable_plans.each do |key, config|
      price = Stripe::Price.create(
        product: product.id,
        unit_amount: config[:price],
        currency: "jpy",
        recurring: { interval: "month" },
        metadata: { plan_type: key.to_s, catalog_price: config[:price].to_s }
      )
      env_key = config[:stripe_price_env]
      puts "#{env_key}=#{price.id}  # #{config[:name]} ¥#{config[:price]}/月"
    end
    puts "\n作成後: bundle exec rake stripe:validate_plans"
  end
end
