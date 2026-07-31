require "rails_helper"

RSpec.describe DealFollowUp::CancelRemainingService do
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
  let(:user_progress) { deal.user_progresses.create!(user: user, follow_up_unsubscribe_token: "token123") }
  let!(:sent) do
    user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: deal.deal_follow_up_templates.find_by!(sequence: 1),
      sequence: 1,
      subject: "sent",
      body: "body",
      scheduled_at: 1.day.ago,
      status: "sent",
      sent_at: 1.day.ago
    )
  end
  let!(:pending) do
    user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: deal.deal_follow_up_templates.find_by!(sequence: 2),
      sequence: 2,
      subject: "pending",
      body: "body",
      scheduled_at: 3.days.from_now,
      status: "scheduled"
    )
  end

  it "cancels only scheduled deliveries" do
    expect {
      described_class.call(user_progress: user_progress, source: "contract_click")
    }.to change { pending.reload.status }.from("scheduled").to("cancelled")

    expect(sent.reload.status).to eq("sent")
    expect(user_progress.reload.follow_up_unsubscribed_at).to be_nil
  end
end
