require "rails_helper"

RSpec.describe DealFollowUp::BodyRenderer do
  let(:client) do
    Client.create!(
      email: "provider@example.com",
      password: "password123",
      name: "テスト太郎",
      company: "テスト株式会社",
      tel: "03-0000-0000",
      address: "東京都"
    )
  end
  let(:deal) do
    client.deals.create!(
      title: "Demo Deal",
      language: "ja",
      presentation_cta_url: "https://example.com/contract",
      follow_up_sales_url: "https://example.com/sales"
    )
  end
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎") }
  let(:user_progress) { deal.user_progresses.create!(user: user, follow_up_unsubscribe_token: "token") }
  let(:template) { deal.deal_follow_up_templates.first }
  let(:delivery) do
    user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: template,
      sequence: 1,
      subject: "Hello {{user_name}}",
      body: "Deal: {{deal_title}}",
      scheduled_at: Time.current,
      status: "scheduled"
    )
  end

  it "includes opt-out copy and cta buttons when urls exist" do
    html = described_class.new(delivery).html_body

    expect(html).to include("担当者に繋ぐ")
    expect(html).to include("契約を進める")
    expect(html).to include("興味がない・導入を見送る場合はこちら")
  end

  it "appends session summary when available" do
    user_progress.update!(
      prospect_grade: "A",
      prospect_score: 88,
      session_summary: {
        "challenge" => "営業属人化",
        "interest" => "自動化",
        "consideration" => "料金",
        "next_action" => "トライアル"
      },
      session_analyzed_at: Time.current
    )

    text = described_class.new(delivery).text_body
    expect(text).to include("見込み度 A")
    expect(text).to include("課題：営業属人化")
    expect(text).to include("次アクション：トライアル")
  end

  it "hides contract button when contract url is blank" do
    deal.update!(presentation_cta_url: nil)
    html = described_class.new(delivery).html_body

    expect(html).not_to include("契約を進める")
  end
end
