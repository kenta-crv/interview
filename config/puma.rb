# Puma configuration
# https://puma.io/puma/Puma/DSL.html

max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT") { 3000 }

environment ENV.fetch("RAILS_ENV") { "development" }

pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Puma 6+ は ENV["WEB_CONCURRENCY"] があると workers のデフォルトになる。
# macOS の development で cluster mode (fork) すると ObjC/Swift 初期化で
# ワーカーが落ちるため、本番以外では明示的にシングルプロセスにする。
if ENV.fetch("RAILS_ENV", "development") == "production"
  workers ENV.fetch("WEB_CONCURRENCY") { 2 }
  preload_app!

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end
else
  workers 0
end

plugin :tmp_restart
