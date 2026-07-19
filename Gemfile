source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1.7'
# PostgreSQL（本番）。開発でも production 検証できるよう常時インストール
gem 'pg', '~> 1.5'
# Use sqlite3 for development/test
gem 'sqlite3', '~> 1.6', groups: [:development, :test]
# Use Puma as the app server
gem 'puma', '~> 6.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 6.0'
# Use JavaScript bundler
gem 'jsbundling-rails'
# Use CSS bundler
gem 'cssbundling-rails'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby
gem 'rake', '~> 13.3'

# Use Hotwire's SPA and page refresh
gem 'turbo-rails'
# Use Hotwire's modest JavaScript framework
gem 'stimulus-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.11'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.0', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.2'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '~> 4.2'
  gem 'listen', '>= 3.5'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 3.38'
  gem 'selenium-webdriver'
  # Easy installation and use of webdrivers for system tests
  gem 'webdrivers'
  gem 'shoulda-matchers', '~> 6.0'
  gem 'database_cleaner-active_record', '~> 2.1'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'slim-rails'
gem 'kaminari'

gem 'devise'
gem 'omniauth-twitter'

gem 'meta-tags'

gem 'httparty'      # API呼び出し用
# VPS等で .env から本番設定を読む（クラウドの環境変数注入がある場合も無害）
gem 'dotenv-rails'
gem 'kramdown'

# Gemfile

# 非同期処理ライブラリ
gem 'sidekiq' 

# Sidekiqで定期実行を実現するライブラリ
gem 'sidekiq-cron' 

gem 'ruby-openai'
gem 'pdf-reader'

gem 'sitemap_generator'
gem 'breadcrumbs_on_rails'
gem 'friendly_id', '~> 5.5'
gem 'carrierwave'
gem 'rack-attack'

gem 'rack-cors'
gem 'rack-attack'
gem 'redis', '~> 4.0'
gem 'aws-sdk-s3', require: false
gem "dotenv", "~> 2.8"
gem 'bullet'

gem 'stripe'

gem 'nokogiri'

