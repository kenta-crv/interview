require "rails_helper"

RSpec.describe "Public deal evaluate emails", type: :request do
  let(:client) do
    Client.create!(
      email: "owner_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      name: "担当太郎",
      company: "販売株式会社",
      tel: "03-0000-0000",
      address: "東京都"
    )
  end

  let(:deal) do
    Deal.create!(
      client: client,
      title: "Demo Deal",
      language: "ja",
      status: :completed,
      playback_ready: true,
      managed_by_admin: true,
      client_id: nil
    )
  end

  let!(:admin) do
    Admin.find_or_create_by!(email: "admin_eval_#{SecureRandom.hex(4)}@example.com") do |a|
      a.password = "password123"
    end
  end

  let!(:deal_page) do
    doc = deal.deal_documents.create!(filename: "test.pdf", content_type: "application/pdf")
    deal.deal_pages.create!(deal_document: doc, page_number: 1, title: "表紙", script: "hello")
  end

  before do
    client.subscriptions.create!(plan_type: :business, status: :active) if client.persisted?
    allow(DealFollowUpMailer).to receive_message_chain(:follow_up, :deliver_now)
    ActionMailer::Base.deliveries.clear
  end

  def register_lead!(email)
    post create_user_info_public_deal_session_path(token: deal.access_token), params: {
      user: {
        name: "見込花子",
        job_title: "部長",
        company: "見込み株式会社",
        email: email,
        tel: "090-1111-2222",
        address: "東京都",
        url: "https://lead.example.com"
      },
      consideration_phase: "evaluation",
      planned_introduction_date: "1ヶ月以内",
      key_points_for_application: "料金"
    }
  end

  it "emails the owner immediately on evaluate and enqueues customer follow-up" do
    register_lead!("lead_eval_#{SecureRandom.hex(4)}@example.com")
    expect(response).to redirect_to(conversation_public_deal_session_path(token: deal.access_token))

    expect {
      post evaluate_public_deal_session_path(token: deal.access_token),
           params: { rating: 5, feedback: "良い" },
           as: :json
    }.to change { ActionMailer::Base.deliveries.size }.by(1)

    expect(response).to have_http_status(:ok)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to include("AI商談が終了しました")
    expect(FollowUpDelivery.where(status: "sent").count).to be >= 1
  end
end
