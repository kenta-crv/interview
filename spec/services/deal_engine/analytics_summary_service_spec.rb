require "rails_helper"

RSpec.describe DealEngine::AnalyticsSummaryService do
  let(:client) do
    Client.create!(
      email: "analytics_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      name: "分析太郎",
      company: "分析株式会社",
      tel: "03-0000-0000",
      address: "東京都"
    )
  end

  let(:deal) do
    Deal.create!(
      client: client,
      title: "分析用商談",
      language: "ja",
      status: :completed,
      playback_ready: true,
      page_views_count: 10
    )
  end

  let!(:page) do
    doc = deal.deal_documents.create!(filename: "a.pdf", content_type: "application/pdf")
    deal.deal_pages.create!(deal_document: doc, page_number: 2, title: "料金", script: "料金です")
  end

  let(:user) do
    User.create!(
      email: "lead_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      name: "リード太郎",
      job_title: "部長",
      company: "リード株式会社"
    )
  end

  let!(:progress) { UserProgress.create!(user: user, deal: deal, prospect_grade: "A", prospect_score: 90) }

  before do
    DealEvaluation.create!(deal: deal, user: user, rating: 4, feedback: "良い")

    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: progress,
      session_key: "sess-1",
      event_type: "presentation_start",
      page_number: 1,
      occurred_at: 1.hour.ago,
      metadata: {}
    )
    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: progress,
      session_key: "sess-1",
      event_type: "cta_click",
      label: "契約",
      occurred_at: 50.minutes.ago,
      metadata: {}
    )
    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: progress,
      session_key: "sess-1",
      event_type: "session_close",
      page_number: 2,
      occurred_at: 40.minutes.ago,
      metadata: {
        "current_page_number" => 2,
        "duration_ms" => 120_000,
        "evaluated" => true
      }
    )
    DealPresentationEvent.create!(
      deal: deal,
      user: user,
      user_progress: progress,
      session_key: "preview-1",
      event_type: "presentation_start",
      page_number: 1,
      occurred_at: 30.minutes.ago,
      metadata: { "preview" => true }
    )
  end

  it "集計指標と離脱ページを返す" do
    result = described_class.call(deal_ids: [deal.id])

    expect(result[:page_views]).to eq(10)
    expect(result[:leads_count]).to eq(1)
    expect(result[:sessions_started]).to eq(1)
    expect(result[:sessions_completed]).to eq(1)
    expect(result[:lead_rate]).to eq(10.0)
    expect(result[:start_rate]).to eq(100.0)
    expect(result[:completion_rate]).to eq(100.0)
    expect(result[:high_prospect_count]).to eq(1)
    expect(result[:average_evaluation]).to eq(4.0)
    expect(result[:cta_clicks]).to eq(1)
    expect(result[:average_duration_label]).to eq("2分")
    expect(result[:drop_offs].first[:page_number]).to eq(2)
    expect(result[:drop_offs].first[:title]).to eq("料金")
    expect(result[:drop_offs].first[:count]).to eq(1)
    expect(result[:funnel_segments].map { |s| s[:key] }).to include("visit_only", "completed")
    expect(result[:funnel_segments].sum { |s| s[:count] }).to eq(10)
  end
end
