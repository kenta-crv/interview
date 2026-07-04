class Client < ApplicationRecord
  include PlanLimitable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :situations, dependent: :destroy
  has_many :deals, dependent: :destroy

  has_many :subscriptions, dependent: :destroy
  has_one :active_subscription, -> { where(status: :active) }, class_name: "Subscription"
  has_many :payments, dependent: :destroy

  def subscription_plan
    current_subscription&.plan_type
  end

  def subscription_status
    current_subscription&.status
  end

  def trial_ends_at
    current_subscription&.trial_ends_at
  end

  def client?
    true
  end

  def current_subscription
    active_subscription || subscriptions.order(created_at: :desc).first
  end

  def on_trial?
    subscription_plan == "trial" && trial_ends_at.present? && trial_ends_at > Time.current
  end

  def subscription_active?
    subscription_status == "active"
  end

  def check_and_upgrade_expired_trial
    return unless subscription_plan == "trial"
    return unless trial_ends_at.present?
    return if trial_ends_at > Time.current

    unless stripe_customer_id.present?
      Rails.logger.error "Client #{id} trial expired but no Stripe customer ID found"
      return nil
    end

    begin
      upgrade_plan = Subscription.plan_config(:trial)&.dig(:post_trial_plan) || :standard
      amount = Subscription::PLAN_PRICES[upgrade_plan]

      charge = Stripe::Charge.create(
        amount: amount,
        currency: "jpy",
        customer: stripe_customer_id,
        description: "#{Subscription::PLAN_NAMES[upgrade_plan]} subscription (trial upgrade)"
      )

      if charge.status == "succeeded"
        subscriptions.where(status: :active).update_all(status: :cancelled)

        subscription = subscriptions.create!(
          plan_type: upgrade_plan,
          status: :active,
          stripe_subscription_id: charge.id,
          trial_ends_at: nil
        )

        payments.create!(
          amount: amount,
          stripe_payment_intent_id: charge.id,
          status: "succeeded",
          description: "#{Subscription::PLAN_NAMES[upgrade_plan]} subscription (trial upgrade)"
        )

        Rails.logger.info "Client #{id} trial expired, charged #{amount} JPY via Stripe and upgraded to #{upgrade_plan} plan"
        subscription
      else
        Rails.logger.error "Client #{id} trial expired but Stripe charge failed: #{charge.failure_message}"

        subscriptions.where(status: :active).update_all(status: :cancelled)

        subscriptions.create!(
          plan_type: upgrade_plan,
          status: :active,
          trial_ends_at: nil
        )

        nil
      end
    rescue => e
      Rails.logger.error "Error upgrading trial via Stripe for client #{id}: #{e.message}"
      nil
    end
  end

  def new_account?
    return true if created_at.nil?

    created_at > Subscription::TRIAL_DAYS.days.ago
  end

  after_create :initialize_trial_subscription
  before_create :generate_api_key_if_blank

  private

  def generate_api_key_if_blank
    self.api_key = SecureRandom.hex(32) if api_key.blank?
  end

  def initialize_trial_subscription
    subscriptions.create!(
      plan_type: :trial,
      status: :active,
      trial_ends_at: Subscription::TRIAL_DAYS.days.from_now
    )
  end
end
