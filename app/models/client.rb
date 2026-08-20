class Client < ApplicationRecord
  include PlanLimitable

  LOCALES = %w[ja en].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2 microsoft_graph]
  has_many :situations, dependent: :destroy
  has_many :deals, dependent: :destroy

  has_many :subscriptions, dependent: :destroy
  has_one :active_subscription, -> { where(status: :active) }, class_name: "Subscription"
  has_many :payments, dependent: :destroy

  validates :preferred_locale, inclusion: { in: LOCALES }

  def self.from_omniauth(auth, preferred_locale: "ja")
    email = auth.info.email.to_s.downcase.presence
    raise ArgumentError, "OAuth email missing" if email.blank?

    client = find_by(provider: auth.provider, uid: auth.uid)
    return client if client

    client = find_by(email: email)
    if client
      client.update!(provider: auth.provider, uid: auth.uid)
      client.name = auth.info.name if client.name.blank? && auth.info.name.present?
      client.preferred_locale = preferred_locale if client.preferred_locale.blank?
      client.save! if client.changed?
      return client
    end

    create!(
      email: email,
      password: Devise.friendly_token[0, 20],
      name: auth.info.name,
      provider: auth.provider,
      uid: auth.uid,
      preferred_locale: preferred_locale
    )
  end

  def password_required?
    return false if provider.present?

    super
  end

  def ui_locale
    value = self[:preferred_locale].presence || "ja"
    (LOCALES.include?(value) ? value : "ja").to_sym
  end

  def send_devise_notification(notification, *args)
    I18n.with_locale(ui_locale) { super }
  end

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

  def trial_expired_without_paid?
    subscription = current_subscription
    return true if subscription&.expired?
    return true if subscription_plan == "trial" && trial_ends_at.present? && trial_ends_at <= Time.current

    false
  end

  def subscription_active?
    subscription_status == "active"
  end

  def check_and_upgrade_expired_trial
    return unless subscription_plan == "trial"
    return unless trial_ends_at.present?
    return if trial_ends_at > Time.current

    current_subscription&.expire_trial_without_charge!
  end

  def new_account?
    return true if created_at.nil?

    created_at > Subscription::TRIAL_DAYS.days.ago
  end

  def used_trial?
    subscriptions.exists?(plan_type: :trial)
  end

  def trial_start_available?
    !used_trial?
  end

  def intro_discount_eligible?
    return false if subscriptions.where.not(plan_type: :trial).exists?

    on_trial? || trial_expired_without_paid?
  end

  def dashboard_accessible?
    subscription = subscriptions.find_by(status: :active) || current_subscription
    return false unless subscription
    return false if subscription.trial_expired? && !subscription.expired?
    return true if on_trial?
    return true if subscription.active? && subscription.stripe_subscription_id.present?

    subscription.expired?
  end

  def initialize_trial_subscription!
    return current_subscription if subscriptions.where(plan_type: :trial).exists?

    subscription = subscriptions.create!(
      plan_type: :trial,
      status: :active,
      trial_ends_at: Subscription::TRIAL_DAYS.days.from_now
    )
    update_columns(subscription_plan: "trial", subscription_status: "active")
    subscription
  end

  def reconcile_invalid_subscriptions!
    subscriptions.where(status: :active, stripe_subscription_id: nil).update_all(status: :cancelled)
  end

  def subscription_cancellable?
    subscriptions.exists?(status: :active) || on_trial?
  end

  def company_or_email
    company.presence || email
  end

  def update_company_name(value)
    name = value.to_s.strip
    return false if name.blank?
    return true if company == name

    update(company: name)
  end

  validates :company, :name, :tel, :address, presence: true, on: :profile_update
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

  before_create :generate_api_key_if_blank
  after_create :bootstrap_trial_subscription

  private

  def generate_api_key_if_blank
    self.api_key = SecureRandom.hex(32) if api_key.blank?
  end

  def bootstrap_trial_subscription
    initialize_trial_subscription!
  end
end
