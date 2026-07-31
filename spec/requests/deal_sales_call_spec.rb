require "rails_helper"

RSpec.describe "Public deal sales call request", type: :request do
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
      playback_ready: true
    )
  end

  let!(:deal_page) do
    doc = deal.deal_documents.create!(filename: "test.pdf", content_type: "application/pdf")
    deal.deal_pages.create!(deal_document: doc, page_number: 1, title: "表紙", script: "hello")
  end

  before do
    ActionMailer::Base.deliveries.clear
  end

  it "emails the client with lead details immediately" do
    email = "lead_#{SecureRandom.hex(4)}@example.com"

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
      key_points_for_application: "料金・費用対効果"
    }
    expect(response).to redirect_to(conversation_public_deal_session_path(token: deal.access_token))

    expect {
      post request_sales_call_public_deal_session_path(token: deal.access_token),
           params: { session_key: "sess_test", source: "header" },
           as: :json
    }.to change { ActionMailer::Base.deliveries.size }.by(1)

    expect(response).to have_http_status(:ok)
    expect(deal.deal_presentation_events.where(event_type: "exit_sales_call_click").count).to eq(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([client.email])
    expect(mail.subject).to include("担当者商談の希望")
  end

  it "does not email in preview mode" do
    sign_in client

    expect {
      post request_sales_call_public_deal_session_path(token: deal.access_token, preview: 1),
           params: { session_key: "sess_preview" },
           as: :json
    }.not_to change { ActionMailer::Base.deliveries.size }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["preview"]).to eq(true)
  end
end
