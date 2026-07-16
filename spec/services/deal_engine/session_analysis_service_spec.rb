require "rails_helper"

RSpec.describe DealEngine::SessionAnalysisService do
  let(:client) do
    Client.create!(
      email: "biz@example.com",
      password: "password123",
      name: "テスト太郎",
      company: "テスト株式会社",
      tel: "03-0000-0000",
      address: "東京都"
    )
  end
  let(:deal) { client.deals.create!(title: "Demo Deal", language: "ja") }
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎") }
  let(:user_progress) do
    deal.user_progresses.create!(
      user: user,
      consideration_phase: :evaluation,
      key_points_for_application: "導入工数を減らしたい"
    )
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: user_progress,
      session_key: "sess1",
      event_type: "topic_click",
      label: "料金プラン",
      page_number: 2,
      occurred_at: 3.minutes.ago
    )
    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: user_progress,
      session_key: "sess1",
      event_type: "free_text_send",
      message: "導入まで何日かかりますか？",
      occurred_at: 2.minutes.ago
    )
    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: user_progress,
      session_key: "sess1",
      event_type: "cta_click",
      occurred_at: 1.minute.ago
    )
    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: user_progress,
      session_key: "sess1",
      event_type: "session_close",
      metadata: { "duration_ms" => 240_000, "evaluated" => true },
      occurred_at: Time.current
    )
  end

  it "stores prospect grade and summary fields" do
    result = described_class.call(user_progress: user_progress)
    user_progress.reload

    expect(result[:grade]).to be_in(%w[A B C D])
    expect(user_progress.prospect_grade).to eq(result[:grade])
    expect(user_progress.prospect_score).to be_between(0, 100)
    expect(user_progress.session_summary["challenge"]).to be_present
    expect(user_progress.session_summary["next_action"]).to be_present
    expect(user_progress.session_analyzed_at).to be_present
  end
end
