class CheckoutController < ApplicationController
  layout "dashboard_focus"

  before_action :authenticate_client!

  def confirmation
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'

    @plan_type = params[:plan_type]

    if @plan_type.blank?
      redirect_to plans_path, alert: "プランを選択してください。"
      return
    end

    unless Subscription::PLAN_CATALOG.key?(@plan_type.to_sym)
      redirect_to plans_path, alert: "無効なプランです。"
      return
    end

    @plan_config = Subscription.plan_config(@plan_type)
    @amount = @plan_config[:price]

    if @plan_type == "trial"
      @description = "無料トライアル (#{Subscription::TRIAL_DAYS}日間)"
      @amount = 0

      if current_client.new_account? == false || current_client.subscriptions.where(plan_type: :trial).exists?
        redirect_to plans_path,
                    alert: "無料トライアルは新規アカウントのみ利用できます。"
        return
      end
    else
      @description = @plan_config[:name]
    end

    @subscription = Subscription.new(plan_type: @plan_type)
  end

  def create
    plan_type = params[:plan_type]

    Rails.logger.info("[Checkout#create] plan_type=#{plan_type}")

    if plan_type.blank?
      redirect_to plans_path, alert: "プランを選択してください。"
      return
    end

    unless Subscription::PLAN_CATALOG.key?(plan_type.to_sym)
      redirect_to plans_path, alert: "無効なプランです。"
      return
    end

    if plan_type == "trial"
      process_trial_checkout!
      return
    end

    begin
      process_subscription_payment(plan_type)
    rescue Stripe::CardError => e
      Rails.logger.error("[Stripe Card Error] #{e.class} #{e.message}")
      redirect_to checkout_confirmation_path(plan_type: plan_type), alert: "カード決済に失敗しました: #{e.message}"
    rescue Stripe::StripeError => e
      Rails.logger.error("[Stripe API Error] #{e.class} #{e.message}")
      redirect_to checkout_confirmation_path(plan_type: plan_type), alert: "Stripe決済エラー: #{e.message}"
    rescue => e
      Rails.logger.error("[Checkout Error] #{e.class} #{e.message}")
      redirect_to checkout_confirmation_path(plan_type: plan_type), alert: "決済処理中にエラーが発生しました。"
    end
  end

  def success
    session_id = params[:session_id]

    if session_id.blank?
      @subscription = current_client.subscriptions.order(created_at: :desc).first
      @payment = current_client.payments.order(created_at: :desc).first
      @amount = @payment&.amount || 0
      @invoice_id = @payment&.stripe_payment_intent_id
      @plan_name = @subscription&.plan_name || "プラン"
      return
    end

    begin
      @session = Stripe::Checkout::Session.retrieve(session_id)

      @amount = @session.amount_total
      @invoice_id = @session.invoice || @session.payment_intent

      @plan_type = @session.metadata["plan_type"]
      @payment_type = @session.metadata["payment_type"]

      if @payment_type == "subscription" && @plan_type.present?
        @plan_name = Subscription::PLAN_NAMES[@plan_type.to_sym] rescue @plan_type.to_s
      else
        @plan_name = "決済"
      end

      if @session.payment_status == "paid"
        if @payment_type == "subscription" && @plan_type.present? && @session.subscription.present?

          Subscription.transaction do
            sub = current_client.subscriptions.find_or_initialize_by(stripe_subscription_id: @session.subscription)
            current_client.subscriptions.where.not(id: sub.id).update_all(status: :cancelled)

            sub.update!(plan_type: @plan_type, status: :active, trial_ends_at: nil)

            current_client.update!(
              subscription_plan: @plan_type,
              subscription_status: "active"
            )
          end

          @subscription = current_client.subscriptions.find_by(stripe_subscription_id: @session.subscription)
        end
      end

      @payment = current_client.payments.find_by(stripe_payment_intent_id: @invoice_id) || current_client.payments.order(created_at: :desc).first

    rescue Stripe::StripeError => e
      Rails.logger.error("[Stripe Success Retrieve Error] #{e.message}")
      @plan_name = "プラン"
      @amount = 0
      @invoice_id = "N/A"
    end
  end

  def cancel
    redirect_to plans_path, alert: "決済がキャンセルされました。"
  end

  private

  def activate_trial!
    process_trial_checkout!
  end

  def process_trial_checkout!
    unless current_client.new_account?
      redirect_to plans_path, alert: "無料トライアルは新規アカウントのみ利用できます。"
      return
    end

    if current_client.subscriptions.where(plan_type: :trial).exists?
      redirect_to plans_path, alert: "無料トライアルは既に利用済みです。"
      return
    end

    post_trial_plan = Subscription.plan_config(:trial)&.dig(:post_trial_plan) || :standard
    stripe_price_id = Subscription.stripe_price_id_for(post_trial_plan)

    unless stripe_price_id.present?
      redirect_to plans_path, alert: "Stripe Price ID が未設定です。"
      return
    end

    customer = ensure_stripe_customer!

    session = Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: customer.id,
      payment_method_types: ["card"],
      line_items: [{ price: stripe_price_id, quantity: 1 }],
      subscription_data: { trial_period_days: Subscription::TRIAL_DAYS },
      metadata: {
        client_id: current_client.id,
        plan_type: "trial",
        payment_type: "subscription"
      },
      success_url: "#{checkout_success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: checkout_cancel_url
    )

    redirect_to session.url, allow_other_host: true
  end

  def process_subscription_payment(plan_type)
    stripe_price_id = Subscription.stripe_price_id_for(plan_type)

    unless stripe_price_id.present?
      redirect_to plans_path, alert: "Stripe Price ID が未設定です（#{Subscription.plan_config(plan_type)[:stripe_price_env]}）。"
      return
    end

    begin
      StripePlanValidator.validate!(plan_type)
    rescue StripePlanValidator::ConfigurationError => e
      Rails.logger.error("[Checkout] Stripe plan mismatch: #{e.message}")
      redirect_to plans_path, alert: "Stripeの料金設定がプラン定義と一致しません。管理者に連絡してください。"
      return
    end

    customer = ensure_stripe_customer!

    session = Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: customer.id,
      payment_method_types: ["card"],
      line_items: [{ price: stripe_price_id, quantity: 1 }],
      metadata: {
        client_id: current_client.id,
        plan_type: plan_type.to_s,
        payment_type: "subscription"
      },
      success_url: "#{checkout_success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: checkout_cancel_url
    )

    redirect_to session.url, allow_other_host: true
  end

  def ensure_stripe_customer!
    if current_client.stripe_customer_id.present?
      Stripe::Customer.retrieve(current_client.stripe_customer_id)
    else
      customer = Stripe::Customer.create(email: current_client.email, metadata: { client_id: current_client.id })
      current_client.update!(stripe_customer_id: customer.id)
      customer
    end
  end
end
