require "rails_helper"

RSpec.describe Public::FollowUpTrackingController, type: :request do
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
  let(:deal) { client.deals.create!(title: "Demo Deal", language: "ja", presentation_cta_url: "https://example.com/contract") }
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎", job_title: "担当者") }
  let(:user_progress) { deal.user_progresses.create!(user: user, follow_up_unsubscribe_token: "unsub-token") }
  let!(:delivery) do
    user_progress.follow_up_deliveries.create!(
      deal_follow_up_template: deal.deal_follow_up_templates.first,
      sequence: 1,
      subject: "test",
      body: "body",
      scheduled_at: Time.current,
      status: "sent",
      sent_at: Time.current
    )
  end

  describe "GET /follow_up/o/:token" do
    it "marks delivery as opened" do
      get follow_up_open_path(delivery.tracking_token)

      expect(response).to have_http_status(:ok)
      expect(delivery.reload.opened_at).to be_present
    end
  end

  describe "GET /follow_up/c/:token" do
    let!(:pending) do
      user_progress.follow_up_deliveries.create!(
        deal_follow_up_template: deal.deal_follow_up_templates.find_by!(sequence: 2),
        sequence: 2,
        subject: "later",
        body: "body",
        scheduled_at: 3.days.from_now,
        status: "scheduled"
      )
    end

    it "records contract click, cancels remaining, and redirects" do
      get follow_up_click_path(delivery.contract_click_token)

      expect(response).to redirect_to("https://example.com/contract")
      expect(delivery.reload.contract_clicked_at).to be_present
      expect(pending.reload.status).to eq("cancelled")
    end

    it "records sales click, cancels remaining, and redirects" do
      deal.update!(follow_up_sales_url: "https://example.com/sales")
      get follow_up_click_path(delivery.sales_click_token)

      expect(response).to redirect_to("https://example.com/sales")
      expect(delivery.reload.sales_call_clicked_at).to be_present
      expect(pending.reload.status).to eq("cancelled")
    end
  end

  describe "GET /follow_up/unsubscribe/:token" do
    it "unsubscribes and renders confirmation page" do
      get follow_up_unsubscribe_path("unsub-token")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ご意向を受け付けました")
      expect(user_progress.reload.follow_up_unsubscribed_at).to be_present
    end
  end
end
