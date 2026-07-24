# frozen_string_literal: true

# SQLite 向け PRAGMA は SQLite3Adapter の接続時のみ実行する。
# database.yml の `variables:` や after_initialize での生 SQL は使わない
# （PostgreSQL へ漏れて journal_mode エラーになるため）。

ActiveSupport.on_load(:active_record) do
  next unless defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)

  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(Module.new do
    def configure_connection
      super
      execute("PRAGMA journal_mode = WAL", "SCHEMA")
      execute("PRAGMA synchronous = NORMAL", "SCHEMA")
    end
  end)
end
