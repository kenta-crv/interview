require "rails_helper"

RSpec.describe DealPresentationEvent, type: :model do
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
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎", job_title: "担当者") }
  let(:user_progress) { deal.user_progresses.create!(user: user) }

  before do
    client.subscriptions.create!(plan_type: :business, status: :active)
    ActiveJob::Base.queue_adapter = :test
  end

  it "enqueues follow up campaign and session analysis on evaluated session close" do
    expect {
      described_class.create!(
        deal: deal,
        user: user,
        user_progress: user_progress,
        session_key: "abc",
        event_type: "session_close",
        occurred_at: Time.current,
        metadata: { "evaluated" => true, "rating" => 5 }
      )
    }.to have_enqueued_job(DealFollowUp::SendDeliveryJob).at_least(:once)
      .and have_enqueued_job(AnalyzeUserProgressSessionJob).with(user_progress.id)
  end

  it "enqueues session analysis on unevaluated session close" do
    expect {
      described_class.create!(
        deal: deal,
        user: user,
        user_progress: user_progress,
        session_key: "abc2",
        event_type: "session_close",
        occurred_at: Time.current,
        metadata: { "evaluated" => false }
      )
    }.to have_enqueued_job(AnalyzeUserProgressSessionJob).with(user_progress.id)
  end

  it "does not enqueue follow up on session close without evaluation" do
    expect {
      described_class.create!(
        deal: deal,
        user: user,
        user_progress: user_progress,
        session_key: "abc3",
        event_type: "session_close",
        occurred_at: Time.current,
        metadata: { "evaluated" => false }
      )
    }.not_to have_enqueued_job(DealFollowUp::SendDeliveryJob)
  end

  it "does not enqueue on other exit events" do
    expect {
      described_class.create!(
        deal: deal,
        user: user,
        user_progress: user_progress,
        session_key: "abc4",
        event_type: "exit_contract_click",
        occurred_at: Time.current
      )
    }.not_to have_enqueued_job(DealFollowUp::SendDeliveryJob)
  end
end
