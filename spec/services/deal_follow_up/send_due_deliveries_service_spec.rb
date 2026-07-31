require "rails_helper"

RSpec.describe DealFollowUp::SendDueDeliveriesService do
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
  let!(:template) do
    deal.deal_follow_up_templates.find_by!(sequence: 1)
  end

  before do
    client.subscriptions.create!(plan_type: :business, status: :active)
    allow(DealFollowUpMailer).to receive_message_chain(:follow_up, :deliver_now)
  end

  it "sends deliveries whose scheduled_at has arrived" do
    due = user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: template,
      sequence: 1,
      subject: template.subject,
      body: template.body,
      scheduled_at: 1.minute.ago,
      status: "scheduled"
    )
    future = user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: deal.deal_follow_up_templates.find_by!(sequence: 2),
      sequence: 2,
      subject: "later",
      body: "later",
      scheduled_at: 1.day.from_now,
      status: "scheduled"
    )

    described_class.call

    expect(due.reload.status).to eq("sent")
    expect(future.reload.status).to eq("scheduled")
  end
end
