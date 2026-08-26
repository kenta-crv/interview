require "rails_helper"

RSpec.describe DealEngine::FaqFromEventsService do
  let(:client) { create(:client) }
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
  let(:client) { create(:client) }
  let(:deal) { client.deals.create!(title: "Stress Deal", language: "ja") }

  it "creates pending faqs for uncovered tough questions" do
    deal.create_deal_summary!(summary: "テスト要約", key_points: "要点")

    result = described_class.new(deal, client: client, limit: 3).run!
    expect(result[:tested]).to eq(3)
    expect(deal.deal_faqs.where(source: "stress_test").count).to be >= 1
  end

  it "uses English seed questions for English deals when AI is unavailable" do
    en_deal = client.deals.create!(title: "EN Stress Deal", language: "en")
    en_deal.create_deal_summary!(summary: "English summary", key_points: "key points")

    service = described_class.new(en_deal, client: client, limit: 3)
    allow(service).to receive(:fetch_ai_questions).and_return([])
    result = service.run!

    questions = en_deal.deal_faqs.where(source: "stress_test").pluck(:question)
    expect(result[:tested]).to eq(3)
    expect(questions).not_to be_empty
    expect(questions.join).not_to match(/競合|導入|契約/)
    expect(questions).to all(match(/[A-Za-z]/))
  end
end
