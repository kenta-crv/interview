require "rails_helper"

RSpec.describe DealFollowUp::EnqueueCampaignService do
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
    allow(DealFollowUpMailer).to receive_message_chain(:follow_up, :deliver_now)
  end

  it "creates scheduled deliveries for enabled templates and sends the immediate one" do
    expect {
      described_class.call(user_progress: user_progress, ended_at: Time.zone.parse("2026-07-01 10:00"))
    }.to change(FollowUpDelivery, :count).by(5)

    first = user_progress.follow_up_deliveries.find_by!(sequence: 1)
    second = user_progress.follow_up_deliveries.find_by!(sequence: 2)
    day15 = user_progress.follow_up_deliveries.find_by!(sequence: 4)
    day30 = user_progress.follow_up_deliveries.find_by!(sequence: 5)

    expect(user_progress.reload.session_ended_at).to eq(Time.zone.parse("2026-07-01 10:00"))
    expect(first.scheduled_at).to eq(Time.zone.parse("2026-07-01 10:00"))
    expect(first.status).to eq("sent")
    expect(second.scheduled_at).to eq(Time.zone.parse("2026-07-04 10:00"))
    expect(second.status).to eq("scheduled")
    expect(day15.scheduled_at).to eq(Time.zone.parse("2026-07-16 10:00"))
    expect(day30.scheduled_at).to eq(Time.zone.parse("2026-07-31 10:00"))
  end

  it "does not enqueue twice for the same user progress but still sends pending immediate" do
    allow(DealFollowUpMailer).to receive_message_chain(:follow_up, :deliver_now)
    described_class.call(user_progress: user_progress, ended_at: Time.current)

    expect {
      described_class.call(user_progress: user_progress, ended_at: Time.current)
    }.not_to change(FollowUpDelivery, :count)
  end

  it "skips when plan does not include follow up" do
    client.subscriptions.update_all(plan_type: "starter")
    client.reload

    expect {
      described_class.call(user_progress: user_progress, ended_at: Time.current)
    }.not_to change(FollowUpDelivery, :count)
  end

  it "enqueues when force is true even on starter plan" do
    client.subscriptions.update_all(plan_type: "starter")
    client.reload
    allow(DealFollowUpMailer).to receive_message_chain(:follow_up, :deliver_now)

    expect {
      described_class.call(user_progress: user_progress, ended_at: Time.current, force: true)
    }.to change(FollowUpDelivery, :count).by(5)
  end
end
