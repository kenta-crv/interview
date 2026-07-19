class ApplicationJob < ActiveJob::Base
  # SQLite 開発時のロック競合向け（本番 PostgreSQL では sqlite3 gem が無い）
  if defined?(SQLite3)
    retry_on SQLite3::BusyException, wait: :polynomially_longer, attempts: 8 unless Rails.env.test?
  end
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 5 unless Rails.env.test?
end
