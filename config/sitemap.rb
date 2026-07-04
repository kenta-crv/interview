SitemapGenerator::Sitemap.default_host = "https://meetia.pro"

SitemapGenerator::Sitemap.create do
  add root_path, changefreq: 'weekly', priority: 1.0
  add '/interview', changefreq: 'monthly', priority: 0.8
  add '/plans', changefreq: 'monthly', priority: 0.7
end
