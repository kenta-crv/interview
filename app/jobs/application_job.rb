class ApplicationJob < ActiveJob::Base
  retry_on SQLite3::BusyException, wait: :polynomially_longer, attempts: 8 unless Rails.env.test?
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 5 unless Rails.env.test?
end
