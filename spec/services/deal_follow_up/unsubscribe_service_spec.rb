require "rails_helper"

RSpec.describe DealFollowUp::UnsubscribeService do
  let(:client) { Client.create!(email: "biz@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Demo Deal", language: "ja") }
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎", job_title: "担当者") }
  let(:user_progress) { deal.user_progresses.create!(user: user, follow_up_unsubscribe_token: "token123") }
  let!(:delivery) do
    user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: deal.deal_follow_up_templates.first,
      sequence: 1,
      subject: "test",
      body: "body",
      scheduled_at: 1.day.from_now,
      status: "scheduled"
    )
  end

  it "records unsubscribe history and cancels pending deliveries" do
    expect {
      described_class.call(user_progress: user_progress, source: "email_link")
    }.to change(FollowUpUnsubscribe, :count).by(1)

    expect(user_progress.reload.follow_up_unsubscribed_at).to be_present
    expect(delivery.reload.status).to eq("cancelled")
  end
end
