module DealFollowUpTemplateDefaults
  extend ActiveSupport::Concern

  DEFAULT_TEMPLATES = [
    {
      delay_days: 0,
      subject: "本日はAI商談ありがとうございました",
      body: <<~BODY.strip,
        {{user_name}} 様

        先ほどは「{{deal_title}}」のAI商談にご参加いただき、ありがとうございました。

        【商談サマリー】
        {{session_summary}}

        特に「{{interest_topics}}」について関心をお持ちのようでした。
        次のステップとして「{{next_action}}」をご案内できます。ご不明点があればお気軽にお問い合わせください。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      delay_days: 3,
      subject: "導入に向けたご不明点はございませんか？",
      body: <<~BODY.strip,
        {{user_name}} 様

        先日はAI商談にご参加いただきありがとうございました（見込み度：{{prospect_grade}}）。
        「{{interest_topics}}」について、導入時期や活用方法を担当者が個別にご案内できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      delay_days: 7,
      subject: "ご検討状況はいかがでしょうか",
      body: <<~BODY.strip,
        {{user_name}} 様

        前回のAI商談から少しお時間が経ちました。
        推奨アクションは「{{next_action}}」です。ご検討の進捗に合わせて次のステップをご提案できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: false
    },
    {
      delay_days: 15,
      subject: "その後のご検討状況はいかがでしょうか",
      body: <<~BODY.strip,
        {{user_name}} 様

        「{{deal_title}}」のご検討から2週間ほどが経ちました。
        見込み度は{{prospect_grade}}です。導入判断の材料として、担当者より個別にご説明できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      delay_days: 30,
      subject: "ご導入のタイミングについてご確認です",
      body: <<~BODY.strip,
        {{user_name}} 様

        AI商談から約1か月が経ちました。
        推奨アクションは「{{next_action}}」です。ご都合の良いタイミングで次のステップをご案内できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    }
  ].freeze

  CANONICAL_DELAY_DAYS = DEFAULT_TEMPLATES.map { |attrs| attrs[:delay_days] }.freeze

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
      next if deal_follow_up_templates.exists?(delay_days: attrs[:delay_days])

      sequence = next_follow_up_sequence
      next if sequence.nil?

      deal_follow_up_templates.create!(attrs.merge(sequence: sequence, enabled: true))
    end
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
