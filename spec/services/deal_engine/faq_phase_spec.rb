require "rails_helper"

RSpec.describe DealEngine::IndustryFaqChecklist do
  let(:client) { Client.create!(email: "checklist@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "HR Deal", language: "ja", industry: "hr") }

  it "applies industry-specific checklist items" do
    result = described_class.apply!(deal)
    expect(result[:created]).to eq(4)
    expect(deal.deal_faqs.where(source: "checklist").count).to eq(4)
  end

  it "reports coverage" do
    described_class.apply!(deal)
    faq = deal.deal_faqs.find_by(source: "checklist")
    faq.update!(answer: "テスト回答", status: "approved")

    coverage = described_class.coverage(deal)
    expect(coverage[:total]).to eq(4)
    expect(coverage[:answered]).to eq(1)
  end
end

RSpec.describe DealEngine::FaqFromEventsService do
  let(:client) { Client.create!(email: "events@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Event Deal", language: "ja") }

  it "creates pending faqs from free text events" do
    deal.deal_presentation_events.create!(
      session_key: "sess-1",
      event_type: "free_text_send",
      message: "導入期間はどのくらいですか",
      occurred_at: Time.current
    )

    result = described_class.new(deal).suggest!
    expect(result[:created]).to eq(1)
    expect(deal.deal_faqs.last.source).to eq("session_log")
  end
end

RSpec.describe DealEngine::BuyerStressTestService do
  let(:client) { Client.create!(email: "stress@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Stress Deal", language: "ja") }

  it "creates pending faqs for uncovered tough questions" do
    deal.create_deal_summary!(summary: "テスト要約", key_points: "要点")

    result = described_class.new(deal, client: client, limit: 3).run!
    expect(result[:tested]).to eq(3)
    expect(deal.deal_faqs.where(source: "stress_test").count).to be >= 1
  end
end
