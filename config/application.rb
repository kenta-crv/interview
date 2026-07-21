require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# dotenv-rails は本番ではデフォルトで .env を読まない。
# VPS運用では .env を使うため、ここで明示的に読み込む。
if defined?(Dotenv)
  Dotenv.load(
    File.expand_path('../.env.production.local', __dir__),
    File.expand_path('../.env.local', __dir__),
    File.expand_path('../.env.production', __dir__),
    File.expand_path('../.env', __dir__)
  )
end

module Smart
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1
    config.active_job.queue_adapter = :sidekiq
    config.autoload_paths << Rails.root.join('app/lib')
    config.autoload_paths << Rails.root.join('app/uploaders')
    config.eager_load_paths << Rails.root.join('app/uploaders')    # Settings in config/environments/* take precedence over those specified here.
    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local
    config.i18n.available_locales = %i[ja en]
    config.i18n.default_locale = :ja
    config.i18n.fallbacks = true
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
    address: 'smtp.lolipop.jp',
    domain: 'okey.work',
    port: 587,
    user_name: 'info@okey.work',
    password: ENV['EMAIL_PASSWORD'],
    authentication: 'plain',
    enable_starttls_auto: true
    }

    config.middleware.use Rack::Attack
  end
end
