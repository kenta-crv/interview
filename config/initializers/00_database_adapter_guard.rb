# frozen_string_literal: true

# SQLite 固有設定が PostgreSQL 接続に混ざると
#   PG::UndefinedObject: unrecognized configuration parameter "journal_mode"
# が接続のたびに起きる。database.yml を綺麗にしても
# DATABASE_URL マージや古い Spring キャッシュで再発しうるため、接続時に必ず除去する。

module Meetia
  module DatabaseAdapterGuard
    SQLITE_ONLY_VARIABLES = %w[
      journal_mode
      synchronous
      busy_timeout
      cache_size
      foreign_keys
      temp_store
      mmap_size
      wal_autocheckpoint
      locking_mode
      recursive_triggers
    ].freeze

    module_function

    def strip_sqlite_variables!(config)
      return config unless config.is_a?(Hash)

      variables = config[:variables] || config["variables"]
      return config if variables.blank?

      cleaned = variables.each_with_object({}) do |(key, value), memo|
        name = key.to_s
        next if SQLITE_ONLY_VARIABLES.include?(name)

        memo[key] = value
      end

      if cleaned.empty?
        config.delete(:variables)
        config.delete("variables")
      else
        config[:variables] = cleaned if config.key?(:variables)
        config["variables"] = cleaned if config.key?("variables")
      end

      config
    end
  end
end

ActiveSupport.on_load(:active_record) do
  begin
    require "active_record/connection_adapters/postgresql_adapter"

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Module.new do
      def configure_connection
        if @config.is_a?(Hash)
          @config = @config.dup
          Meetia::DatabaseAdapterGuard.strip_sqlite_variables!(@config)
        end
        super
      end
    end)
  rescue LoadError
    # pg 未インストール環境ではスキップ
  end

  ActiveRecord::Base.singleton_class.prepend(Module.new do
    def establish_connection(config = nil)
      if config.is_a?(Hash)
        config = config.dup
        adapter = (config[:adapter] || config["adapter"]).to_s
        url = (config[:url] || config["url"]).to_s
        if adapter.match?(/postgre/i) || url.match?(/postgre/i)
          Meetia::DatabaseAdapterGuard.strip_sqlite_variables!(config)
        end
      end
      super(config)
    end
  end)
end
