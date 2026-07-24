namespace :data do
  desc "SQLite(db/development.sqlite3) のデータを DATABASE_URL の PostgreSQL へコピーする"
  task migrate: :environment do
    raise "DATABASE_URL を設定してください（コピー先の PostgreSQL）" if ENV["DATABASE_URL"].blank?

    Rails.application.eager_load!
    configs = Rails.configuration.database_configuration
    sqlite_config = configs.fetch("sqlite") do
      {
        "adapter" => "sqlite3",
        "database" => Rails.root.join("db", "development.sqlite3").to_s,
        "pool" => 5,
        "timeout" => 30000
      }
    end
    pg_config = configs.fetch("development")

    unless pg_config["adapter"].to_s.include?("postgres") || pg_config["url"].to_s.include?("postgres")
      raise "development が PostgreSQL ではありません。DATABASE_URL を確認してください: #{pg_config.inspect}"
    end

    puts "Loading SQLite config..."
    ActiveRecord::Base.establish_connection(sqlite_config)

    models = ActiveRecord::Base.descendants.select do |m|
      m.table_exists? && !m.abstract_class?
    end

    dump = {}
    models.each do |model|
      puts "Dumping #{model.name}..."
      dump[model] = model.unscoped.pluck(Arel.star).map do |row|
        model.column_names.zip(row).to_h
      end
    end

    puts "Switching to PostgreSQL..."
    ActiveRecord::Base.establish_connection(pg_config)

    dump.each do |model, rows|
      next if rows.empty?

      puts "Importing #{model.name} (#{rows.size} rows)..."
      model.insert_all!(rows)
    end

    puts "=== Migration completed successfully ==="
  end
end
