module ApplicationHelper
  def default_meta_tags
    {
      site: "Meetia",
      title: I18n.t("meetia.meta.title"),
      description: I18n.t("meetia.meta.description"),
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

  def english_ui?
    I18n.locale.to_s == "en"
  end

  def client_sign_in_path_for_locale
    english_ui? ? new_client_session_en_path(locale: :en) : new_client_session_path
  end

  def client_sign_up_path_for_locale
    english_ui? ? new_client_registration_en_path(locale: :en) : new_client_registration_path
  end

  def client_password_new_path_for_locale
    english_ui? ? new_client_password_en_path(locale: :en) : new_client_password_path
  end

  def client_session_url_for_locale
    english_ui? ? client_session_en_path(locale: :en) : session_path(:client)
  end

  def client_registration_url_for_locale
    english_ui? ? client_registration_en_path(locale: :en) : registration_path(:client)
  end

  def client_password_url_for_locale
    english_ui? ? client_password_en_path(locale: :en) : password_path(:client)
  end

  def client_password_update_url_for_locale
    english_ui? ? client_password_en_path(locale: :en) : password_path(:client)
  end

  def plans_path_for_locale
    english_ui? ? localized_plans_path(locale: :en) : plans_path
  end

  def select_plan_path_for_locale
    english_ui? ? localized_select_plan_path(locale: :en) : select_plan_path
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
      "inLanguage" => I18n.locale.to_s,
      "address" => organization_postal_address
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

  def organization_postal_address
    if english_ui?
      {
        "@type" => "PostalAddress",
        "addressLocality" => "Minato",
        "addressRegion" => "Tokyo",
        "streetAddress" => "2-2-15 Hamamatsucho 2F",
        "addressCountry" => "JP"
      }
    else
      {
        "@type" => "PostalAddress",
        "addressLocality" => "港区",
        "addressRegion" => "東京都",
        "streetAddress" => "浜松町２丁目２番１５号２Ｆ",
        "addressCountry" => "JP"
      }
    end
  end
end
