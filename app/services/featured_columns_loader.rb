# frozen_string_literal: true

require "net/http"
require "nokogiri"

# LPの注目記事を /columns から自動取得する（失敗時は固定リストへフォールバック）
class FeaturedColumnsLoader
  CACHE_KEY = "meetia/featured_columns/v1"
  CACHE_TTL = 1.hour
  SOURCE_URL = ENV.fetch("MEETIA_COLUMNS_URL", "https://meetia.pro/columns")

  def self.call(limit: 5)
    new(limit: limit).call
  end

  def initialize(limit: 5)
    @limit = limit.to_i.clamp(1, 10)
  end

  def call
    Rails.cache.fetch("#{CACHE_KEY}/#{@limit}", expires_in: CACHE_TTL) do
      fetch_from_columns_index
    end
  rescue StandardError => e
    Rails.logger.warn("[FeaturedColumnsLoader] #{e.class}: #{e.message}")
    []
  end

  private

  def fetch_from_columns_index
    uri = URI(SOURCE_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5
    http.read_timeout = 8

    res = http.request(Net::HTTP::Get.new(uri))
    return [] unless res.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(res.body)
    items = []
    seen = {}

    doc.css("a[href*='/columns/']").each do |a|
      href = a["href"].to_s.split("?").first.to_s
      next unless href.match?(%r{/columns/[^/]+/?\z})

      path = href.sub(%r{\Ahttps?://[^/]+}, "")
      path = "/columns/#{Regexp.last_match(1)}" if path =~ %r{/columns/([^/]+)/?\z}
      next if seen[path]

      title = a.text.to_s.gsub(/\s+/, " ").strip
      next if title.blank? || title.length < 8

      seen[path] = true
      items << { title: title, path: path }
      break if items.size >= @limit
    end

    items
  end
end
