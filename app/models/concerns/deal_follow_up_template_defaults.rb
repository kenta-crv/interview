module DealFollowUpTemplateDefaults
  extend ActiveSupport::Concern

  DEFAULT_TEMPLATES = [
    {
      delay_days: 0,
      subject: "「{{deal_title}}」の次のステップをご案内します",
      body: <<~BODY.strip,
        {{user_name}} 様

        先ほどは「{{deal_title}}」のAI商談にお時間をいただき、ありがとうございました。

        商談で確認いただいた内容を踏まえ、次に進むためのご案内を準備しています。
        契約のご相談も、担当者へのご質問も、下のボタンからすぐ進められます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      delay_days: 3,
      subject: "「{{deal_title}}」導入に向けて、続きをご案内できます",
      body: <<~BODY.strip,
        {{user_name}} 様

        先日はAI商談にご参加いただきありがとうございました。
        導入時期や活用方法について、担当者が個別にご案内できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      delay_days: 7,
      subject: "ご検討状況はいかがでしょうか — {{deal_title}}",
      body: <<~BODY.strip,
        {{user_name}} 様

        前回のAI商談から少しお時間が経ちました。
        ご検討の進捗に合わせて、次のステップをご提案できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: false
    },
    {
      delay_days: 15,
      subject: "「{{deal_title}}」のご判断材料をご用意できます",
      body: <<~BODY.strip,
        {{user_name}} 様

        「{{deal_title}}」のご検討から2週間ほどが経ちました。
        導入判断の材料として、担当者より個別にご説明できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      delay_days: 30,
      subject: "ご導入のタイミング、いま一度ご確認ください",
      body: <<~BODY.strip,
        {{user_name}} 様

        AI商談から約1か月が経ちました。
        ご都合の良いタイミングで、次のステップをご案内できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    }
  ].freeze

  CANONICAL_DELAY_DAYS = DEFAULT_TEMPLATES.map { |attrs| attrs[:delay_days] }.freeze

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
      "担当者／契約のリンク先と、送信するメールが未設定です"
    elsif missing_destination
      "担当者または契約のリンク先URLが未設定です"
    else
      "送信するフォローメールが1通もオンになっていません"
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
    DEFAULT_TEMPLATES.each do |attrs|
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
