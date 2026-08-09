require 'rails_helper'

RSpec.describe 'Visitor registration settings', type: :request do
  let(:client) do
    Client.create!(
      email: "client_#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      name: 'テスト太郎',
      company: 'テスト株式会社',
      tel: '03-0000-0000',
      address: '東京都'
    )
  end

  let(:deal) do
    Deal.create!(
      client: client,
      title: 'AI商談デモ',
      language: 'ja',
      status: :completed,
      playback_ready: true
    )
  end

  let!(:deal_pages) do
    doc = deal.deal_documents.create!(filename: 'test.pdf', content_type: 'application/pdf')
    doc.file.attach(
      io: StringIO.new('%PDF-1.4 test'),
      filename: 'test.pdf',
      content_type: 'application/pdf'
    )
    deal.deal_pages.create!(
      deal_document: doc,
      page_number: 1,
      title: '表紙',
      script: 'ご挨拶です'
    )
  end

  describe 'public registration form' do
    it 'shows only configured fields' do
      deal.update!(
        visitor_info_fields: {
          'company' => 'required',
          'name' => 'optional',
          'job_title' => 'hidden',
          'email' => 'required',
          'tel' => 'hidden',
          'address' => 'hidden',
          'url' => 'hidden',
          'consideration_phase' => 'hidden',
          'planned_introduction_date' => 'hidden',
          'key_points_for_application' => 'hidden'
        }
      )

      get public_deal_session_path(token: deal.access_token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('会社名')
      expect(response.body).to include('お名前')
      expect(response.body).to include('メールアドレス')
      expect(response.body).not_to include('役職')
      expect(response.body).not_to include('ご検討の状況')
    end

    it 'rejects missing required fields' do
      deal.update!(
        visitor_info_fields: Deal::DEFAULT_VISITOR_INFO_FIELDS.merge('company' => 'required', 'email' => 'required')
      )

      post create_user_info_public_deal_session_path(token: deal.access_token), params: {
        user: { name: '太郎', job_title: '部長', email: '' }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('必須')
    end

    it 'skips registration and opens conversation immediately' do
      deal.update!(skip_visitor_registration: true)

      expect {
        get public_deal_session_path(token: deal.access_token)
      }.to change(User, :count).by(1)
        .and change(UserProgress, :count).by(1)

      expect(response).to redirect_to(conversation_public_deal_session_path(token: deal.access_token))
      expect(User.order(:id).last).to be_guest

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('presentation-wrapper')
    end
  end

  describe 'dashboard settings' do
    before { sign_in client }

    it 'updates visitor registration settings' do
      patch update_visitor_registration_settings_dashboard_deal_path(deal), params: {
        deal: {
          skip_visitor_registration: '1',
          visitor_info_fields: {
            company: 'optional',
            name: 'hidden',
            job_title: 'hidden',
            email: 'optional',
            tel: 'hidden',
            address: 'hidden',
            url: 'hidden',
            consideration_phase: 'hidden',
            planned_introduction_date: 'hidden',
            key_points_for_application: 'hidden'
          }
        }
      }

      expect(response).to redirect_to(dashboard_deal_path(deal, anchor: 'visitor-registration'))
      deal.reload
      expect(deal.skip_visitor_registration?).to eq(true)
      expect(deal.visitor_info_field_mode('company')).to eq('optional')
      expect(deal.visitor_info_field_mode('name')).to eq('hidden')
      expect(deal.visitor_registration_required?).to eq(false)
    end
  end
end
