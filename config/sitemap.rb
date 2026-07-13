require 'net/http'
require 'nokogiri'

SitemapGenerator::Sitemap.default_host = "https://meetia.pro"

SitemapGenerator::Sitemap.create do
  add root_path, changefreq: 'weekly', priority: 1.0
  add '/plans', changefreq: 'monthly', priority: 0.7

  add '/columns', changefreq: 'daily', priority: 0.6

  column_codes = []
  page = 1

  loop do
    uri = URI("https://meetia.pro/columns?page=#{page}")
    res = Net::HTTP.get_response(uri)
    break unless res.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(res.body)
    links = doc.css('a[href^="/columns/"]').map { |a| a['href'] }
                .reject { |href| href == '/columns' }
                .map { |href| href.sub('/columns/', '') }

    break if links.empty?

    column_codes.concat(links)
    page += 1
    break if page > 100
  end

  column_codes.uniq.each do |code|
    add "/columns/#{code}",
        changefreq: 'weekly',
        priority: 0.5
  end
end
