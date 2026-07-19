#Payjp.api_key = Rails.application.credentials.dig(:payjp, :secret_key) || ENV['PAYJP_SECRET_KEY']
# fetch だと未設定時に起動・migrate 自体が落ちるため、存在時のみ設定する
if ENV['STRIPE_SECRET_KEY'].present?
  Stripe.api_key = ENV['STRIPE_SECRET_KEY']
else
  Rails.logger.warn('[Stripe] STRIPE_SECRET_KEY が未設定です') if defined?(Rails.logger)
end
