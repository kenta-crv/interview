require "rails_helper"

RSpec.describe DealFollowUp::BodyRenderer do
  let(:client) { Client.create!(email: "provider@example.com", password: "password123") }
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

  it "hides contract button when contract url is blank" do
    deal.update!(presentation_cta_url: nil)
    html = described_class.new(delivery).html_body

    expect(html).not_to include("契約を進める")
  end
end
