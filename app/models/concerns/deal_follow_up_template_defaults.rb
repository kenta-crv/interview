module DealFollowUpTemplateDefaults
  extend ActiveSupport::Concern

  DEFAULT_TEMPLATES = [].freeze

  def default_follow_up_templates
    locale = language.to_s == "en" ? :en : :ja
    items = I18n.with_locale(locale) { I18n.t("meetia.follow_up.templates") }
    Array(items).map do |item|
      hash = item.respond_to?(:symbolize_keys) ? item.symbolize_keys : item
      {
        delay_days: hash[:delay_days].to_i,
        subject: hash[:subject].to_s,
        body: hash[:body].to_s.strip,
        include_sales_call_link: ActiveModel::Type::Boolean.new.cast(hash[:include_sales_call_link]),
        include_contract_link: ActiveModel::Type::Boolean.new.cast(hash[:include_contract_link])
      }
    end
  end

  CANONICAL_DELAY_DAYS = [0, 3, 7, 15, 30].freeze

  LEGACY_CUSTOMER_BODY_MARKERS = [
    "【商談サマリー】",
    "{{session_summary}}",
    "{{interest_topics}}",
    "{{next_action}}",
    "見込み度：{{prospect_grade}}",
    "見込み度は{{prospect_grade}}",
    "興味がない・導入を見送る",
    "特に「",
    "下記ボタンよりお気軽にお知らせください",
    "担当者からの個別ご案内が可能です"
  ].freeze

  def ensure_follow_up_templates!
    remove_legacy_fourteen_day_templates!
    ensure_canonical_follow_up_templates!
    reorder_follow_up_templates_by_delay!
  end

  def follow_up_destination_url_present?
    follow_up_sales_url.to_s.strip.present? || presentation_cta_url.to_s.strip.present?
  end

  def follow_up_templates_enabled?
    deal_follow_up_templates.enabled.exists?
  end

  def follow_up_ready_to_share?
    follow_up_templates_enabled? && follow_up_destination_url_present?
  end

  def follow_up_setup_gaps
    gaps = []
    gaps << :templates unless follow_up_templates_enabled?
    gaps << :destination unless follow_up_destination_url_present?
    gaps
  end

  def follow_up_share_lock_message
    missing_templates = !follow_up_templates_enabled?
    missing_destination = !follow_up_destination_url_present?

    if missing_templates && missing_destination
      I18n.t("meetia.dashboard.follow_up.lock_both")
    elsif missing_destination
      I18n.t("meetia.dashboard.follow_up.lock_destination")
    else
      I18n.t("meetia.dashboard.follow_up.lock_templates")
    end
  end

  private

  def remove_legacy_fourteen_day_templates!
    deal_follow_up_templates.where(delay_days: 14).find_each do |template|
      if template.follow_up_deliveries.exists?
        template.update!(enabled: false)
      else
        template.destroy!
      end
    end
  end

  def ensure_canonical_follow_up_templates!
    default_follow_up_templates.each do |attrs|
      template = deal_follow_up_templates.find_by(delay_days: attrs[:delay_days])
      if template
        refresh_legacy_customer_template!(template, attrs)
        next
      end

      sequence = next_follow_up_sequence
      next if sequence.nil?

      deal_follow_up_templates.create!(attrs.merge(sequence: sequence, enabled: true))
    end
  end

  def refresh_legacy_customer_template!(template, attrs)
    return unless legacy_customer_body?(template.body)

    template.update!(
      subject: attrs[:subject],
      body: attrs[:body],
      include_sales_call_link: attrs[:include_sales_call_link],
      include_contract_link: attrs[:include_contract_link]
    )

    template.follow_up_deliveries.where(status: "scheduled").find_each do |delivery|
      delivery.update!(subject: template.subject, body: template.body)
    end
  end

  def legacy_customer_body?(body)
    text = body.to_s
    LEGACY_CUSTOMER_BODY_MARKERS.any? { |marker| text.include?(marker) }
  end

  def reorder_follow_up_templates_by_delay!
    templates = deal_follow_up_templates.order(:delay_days, :id).to_a
    return if templates.empty?

    templates.each_with_index do |template, index|
      template.update_column(:sequence, 100 + index)
    end

    templates.each_with_index do |template, index|
      template.update_column(:sequence, index + 1)
    end
  end

  def next_follow_up_sequence
    used = deal_follow_up_templates.pluck(:sequence)
    (DealFollowUpTemplate::SEQUENCES.to_a - used).min
  end
end
