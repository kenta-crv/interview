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
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎", job_title: "担当者") }
  let(:user_progress) do
    deal.user_progresses.create!(
      user: user,
      follow_up_unsubscribe_token: "token",
      key_points_for_application: "料金"
    )
  end
  let(:template) { deal.deal_follow_up_templates.first }
  let(:delivery) do
    user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: template,
      sequence: 1,
      subject: "Hello {{user_name}}",
      body: "{{user_name}} 様\n\n先ほどは「{{deal_title}}」のAI商談にお時間をいただきました。",
      scheduled_at: Time.current,
      status: "scheduled"
    )
  end

  before do
    user_progress.update!(
      session_summary: {
        "challenge" => "料金と5名利用時の最適プランが不明",
        "interest" => "機能一覧を確認し、料金質問まで進んだ",
        "consideration" => "導入のしやすさ重視",
        "next_action" => "5名利用時の推奨プランと費用内訳を提示する",
        "topics" => ["機能一覧", "料金"],
        "questions" => ["5名だといくらですか"]
      },
      session_analyzed_at: Time.current
    )
  end

  it "discloses only customer-safe history and keeps CTAs ordered" do
    html = described_class.new(delivery).html_body

    expect(html).to include("ご確認いただいた内容")
    expect(html).to include("機能一覧")
    expect(html).to include("料金")
    expect(html).to include("料金・プランについて、担当者より詳しくご案内できます")

    expect(html).not_to include("課題")
    expect(html).not_to include("機能一覧を確認し、料金質問まで進んだ")
    expect(html).not_to include("5名だといくらですか")
    expect(html).not_to include("推奨プランと費用内訳を提示する")
    expect(html).not_to include("見込み度")

    expect(html.index("契約について相談する")).to be < html.index("担当者に相談する")
    expect(html).to include(">配信停止</a>")
  end

  it "always shows CTA buttons even when destination urls are blank" do
    deal.update!(presentation_cta_url: nil, follow_up_sales_url: nil)
    html = described_class.new(delivery).html_body

    expect(html).to include("契約について相談する")
    expect(html).to include("担当者に相談する")
  end

  it "hides contract button when template disables it" do
    template.update!(include_contract_link: false)
    html = described_class.new(delivery).html_body

    expect(html).to include("担当者に相談する")
    expect(html).not_to include("契約について相談する")
  end
end
