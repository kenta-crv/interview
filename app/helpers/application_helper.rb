module ApplicationHelper
  def default_meta_tags
    {
      site: "Meetia",
      title: "AI商談代行サービス",
      description: "資料アップロードだけで24時間365日、AIが音声商談を代行。商談結果の分析・見込み度判定・自動フォローまで一気通貫で営業工数を削減します。",
      canonical: request.original_url,
      charset: "UTF-8",
      reverse: true,
      separator: '|',
      icon: [
        { href: image_path('favicon.ico') },
        { href: image_path('favicon.ico'), rel: 'apple-touch-icon' },
      ],
    }
  end

  def breadcrumb_list_json_ld
    return if !defined?(breadcrumbs) || breadcrumbs.blank?

    items = breadcrumbs.each_with_index.map do |crumb, i|
      item = {
        "@type" => "ListItem",
        "position" => i + 1,
        "name" => crumb[:label]
      }
      item["item"] = crumb[:path].present? ? "#{request.base_url}#{crumb[:path]}" : request.original_url
      item
    end

    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items
    }.to_json
  end

  def organization_json_ld
    {
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "Meetia",
      "legalName" => "株式会社J Work",
      "url" => "https://meetia.pro/",
      "logo" => "https://meetia.pro#{image_path('favicon.ico')}",
      "description" => default_meta_tags[:description],
      "address" => {
        "@type" => "PostalAddress",
        "addressLocality" => "港区",
        "addressRegion" => "東京都",
        "streetAddress" => "浜松町２丁目２番１５号２Ｆ",
        "addressCountry" => "JP"
      }
    }.to_json
  end

  def website_json_ld
    {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "Meetia",
      "url" => "https://meetia.pro/",
      "inLanguage" => %w[ja en],
      "publisher" => {
        "@type" => "Organization",
        "name" => "株式会社J Work"
      }
    }.to_json
  end

  def faq_page_json_ld(items)
    entities = Array(items).filter_map do |item|
      q = item[:q].to_s.strip
      a = item[:a].to_s.strip
      next if q.blank? || a.blank?

      {
        "@type" => "Question",
        "name" => q,
        "acceptedAnswer" => {
          "@type" => "Answer",
          "text" => a
        }
      }
    end
    return if entities.blank?

    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => entities
    }.to_json
  end
end
