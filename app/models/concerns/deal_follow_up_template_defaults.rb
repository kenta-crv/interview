module DealFollowUpTemplateDefaults
  extend ActiveSupport::Concern

  DEFAULT_TEMPLATES = [
    {
      sequence: 1,
      delay_days: 0,
      subject: "本日はAI商談ありがとうございました",
      body: <<~BODY.strip,
        {{user_name}} 様

        先ほどは「{{deal_title}}」のAI商談にご参加いただき、ありがとうございました。
        ご検討の参考になれば幸いです。ご不明点があればお気軽にお問い合わせください。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      sequence: 2,
      delay_days: 3,
      subject: "導入に向けたご不明点はございませんか？",
      body: <<~BODY.strip,
        {{user_name}} 様

        先日はAI商談にご参加いただきありがとうございました。
        導入時期や活用方法について、担当者が個別にご案内できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    },
    {
      sequence: 3,
      delay_days: 7,
      subject: "ご検討状況はいかがでしょうか",
      body: <<~BODY.strip,
        {{user_name}} 様

        前回のAI商談から少しお時間が経ちました。
        ご検討の進捗に合わせて、次のステップをご提案できます。
      BODY
      include_sales_call_link: true,
      include_contract_link: false
    },
    {
      sequence: 4,
      delay_days: 14,
      enabled: false,
      subject: "最終のご案内",
      body: <<~BODY.strip,
        {{user_name}} 様

        最後のご案内です。ご契約や担当者との商談をご希望の場合は、下記よりお進みください。
      BODY
      include_sales_call_link: true,
      include_contract_link: true
    }
  ].freeze

  def ensure_follow_up_templates!
    return if deal_follow_up_templates.exists?

    DEFAULT_TEMPLATES.each do |attrs|
      deal_follow_up_templates.create!(attrs)
    end
  end
end
