require "rails_helper"

RSpec.describe Public::FollowUpTrackingController, type: :request do
  let(:client) { Client.create!(email: "biz@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Demo Deal", language: "ja", presentation_cta_url: "https://example.com/contract") }
  let(:user) { User.create!(email: "prospect@example.com", password: "password123", name: "太郎") }
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
    it "records contract click and redirects" do
      get follow_up_click_path(delivery.contract_click_token)

      expect(response).to redirect_to("https://example.com/contract")
      expect(delivery.reload.contract_clicked_at).to be_present
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
