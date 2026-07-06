require "rails_helper"

RSpec.describe DealFollowUp::EnqueueCampaignService do
  let(:client) { Client.create!(email: "biz@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Demo Deal", language: "ja") }
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎") }
  let(:user_progress) { deal.user_progresses.create!(user: user) }

  before do
    client.current_subscription.update!(plan_type: :business, status: :active)
  end

  it "creates scheduled deliveries for enabled templates" do
    expect {
      described_class.call(user_progress: user_progress, ended_at: Time.zone.parse("2026-07-01 10:00"))
    }.to change(FollowUpDelivery, :count).by(3)

    first = user_progress.follow_up_deliveries.find_by!(sequence: 1)
    second = user_progress.follow_up_deliveries.find_by!(sequence: 2)

    expect(user_progress.reload.session_ended_at).to eq(Time.zone.parse("2026-07-01 10:00"))
    expect(first.scheduled_at).to eq(Time.zone.parse("2026-07-01 10:00"))
    expect(second.scheduled_at).to eq(Time.zone.parse("2026-07-04 10:00"))
  end

  it "does not enqueue twice for the same user progress" do
    described_class.call(user_progress: user_progress, ended_at: Time.current)

    expect {
      described_class.call(user_progress: user_progress, ended_at: Time.current)
    }.not_to change(FollowUpDelivery, :count)
  end

  it "skips when plan does not include follow up" do
    client.current_subscription.update!(plan_type: :starter)

    expect {
      described_class.call(user_progress: user_progress, ended_at: Time.current)
    }.not_to change(FollowUpDelivery, :count)
  end
end
