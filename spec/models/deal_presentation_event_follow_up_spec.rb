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
    allow(DealFollowUpMailer).to receive_message_chain(:follow_up, :deliver_now)
  end

  it "creates follow up deliveries and sends immediate mail on evaluated session close" do
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
    }.to change(FollowUpDelivery, :count).by(5)
      .and have_enqueued_job(AnalyzeUserProgressSessionJob).with(user_progress.id)

    immediate = user_progress.follow_up_deliveries.find_by!(sequence: 1)
    expect(immediate.status).to eq("sent")
    expect(user_progress.follow_up_deliveries.where(status: "scheduled").count).to eq(4)
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

    expect(FollowUpDelivery.count).to eq(0)
  end

  it "does not create follow up deliveries on session close without evaluation" do
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
    }.not_to change(FollowUpDelivery, :count)
  end

  it "does not create follow up deliveries on other exit events" do
    expect {
      described_class.create!(
        deal: deal,
        user: user,
        user_progress: user_progress,
        session_key: "abc4",
        event_type: "exit_contract_click",
        occurred_at: Time.current
      )
    }.not_to change(FollowUpDelivery, :count)
  end

  it "creates follow up deliveries with admin_force even when plan is trial" do
    client.subscriptions.update_all(plan_type: :trial)

    expect {
      described_class.create!(
        deal: deal,
        user: user,
        user_progress: user_progress,
        session_key: "admin-force",
        event_type: "session_close",
        occurred_at: Time.current,
        metadata: { "evaluated" => true, "admin_force" => true }
      )
    }.to change(FollowUpDelivery, :count).by(5)

    expect(user_progress.follow_up_deliveries.find_by!(sequence: 1).status).to eq("sent")
  end
end
