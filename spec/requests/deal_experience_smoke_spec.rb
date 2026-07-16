require 'rails_helper'

RSpec.describe 'Deal experience smoke', type: :request do
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
      description: 'テスト用商談',
      language: 'ja',
      status: :completed
    )
  end

  let!(:deal_pages) do
    doc = deal.deal_documents.create!(filename: 'test.pdf', content_type: 'application/pdf')
    doc.file.attach(
      io: StringIO.new('%PDF-1.4 test'),
      filename: 'test.pdf',
      content_type: 'application/pdf'
    )
    [
      deal.deal_pages.create!(
        deal_document: doc,
        page_number: 1,
        title: '表紙・ご挨拶',
        script: 'ご挨拶です'
      ),
      deal.deal_pages.create!(
        deal_document: doc,
        page_number: 2,
        title: '会社概要',
        script: '会社概要です'
      )
    ]
  end

  before do
    deal.update!(
      greeting_script: 'こんにちは。AI商談を開始します。',
      company_overview_script: '当社はAI商談支援を提供しています。',
      usage_guide_script: 'ボタンまたは自由質問で進行できます。'
    )
  end

  describe 'public conversation flow' do
    it 'shows registration form without start overlay' do
      get public_deal_session_path(token: deal.access_token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('商談参加登録')
      expect(response.body).not_to include('id="presentation-start-overlay"')
    end

    it 'shows unified deal experience after registration' do
      post create_user_info_public_deal_session_path(token: deal.access_token), params: {
        user: {
          name: 'テスト太郎',
          company: 'テスト株式会社',
          email: "user_#{SecureRandom.hex(4)}@example.com",
          tel: '090-0000-0000',
          address: 'Tokyo',
          url: 'https://example.com'
        },
        consideration_phase: 'initial'
      }

      expect(response).to redirect_to(conversation_public_deal_session_path(token: deal.access_token))

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('presentation-wrapper')
      expect(response.body).to include('btn-choice')
      expect(response.body).to include('presentation-free-text')
      expect(response.body).to include('free-text-input')
      expect(response.body).to include('presentation-topics-bar')
      expect(response.body).to include('こんにちは。AI商談を開始します。')
      expect(response.body).to include('presentation-start-overlay')
      expect(response.body).to include('deal-presentation-config')

      config_match = response.body.match(/id="deal-presentation-config"[^>]*>(.*?)<\/script>/m)
      expect(config_match).to be_present
      parsed_config = JSON.parse(config_match[1])
      expect(parsed_config['pages']).to be_an(Array)
      expect(parsed_config['opening_segments']).to be_an(Array)
      expect(response.body).to include('deal_presentation')
      expect(response.body).to include('presentation-body')
      expect(response.body).to include('#page=')
      expect(response.body).not_to include('custom-navbar')

      post respond_public_deal_session_path(token: deal.access_token), params: {
        topic: 'page_2',
        page_number: 2
      }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['text']).to be_present
      expect(payload['type']).to eq('page')
    end

    it 'allows client preview without registration' do
      sign_in client
      get conversation_public_deal_session_path(token: deal.access_token, preview: 1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('presentation-wrapper')
      expect(response.body).to include('btn-choice')
    end
  end

  describe 'dashboard deal reprocess' do
    before { sign_in client }

    it 'starts reprocess via server-side POST without JavaScript' do
      expect {
        post reprocess_dashboard_deal_path(deal)
      }.to have_enqueued_job(ProcessDealJob).with(deal.id)

      expect(response).to redirect_to(dashboard_deal_path(deal))
      follow_redirect!
      expect(response.body).to include('AI処理中')
      expect(response.body).to include('reprocess')
    end

    it 'renders reprocess button on show page' do
      get dashboard_deal_path(deal)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(reprocess_dashboard_deal_path(deal))
      expect(response.body).to include(upload_documents_dashboard_deal_path(deal))
      expect(response.body).to include('deal_dashboard')
      expect(response.body).not_to include('process-pdf-btn')
    end

    it 'uploads documents via dashboard POST without JavaScript' do
      pdf = Rack::Test::UploadedFile.new(
        StringIO.new('%PDF-1.4 test'),
        'application/pdf',
        true,
        original_filename: 'sample.pdf'
      )

      expect {
        post upload_documents_dashboard_deal_path(deal), params: { files: [pdf] }
      }.to have_enqueued_job(ProcessDealJob).with(deal.id)

      expect(response).to redirect_to(dashboard_deal_path(deal))
      follow_redirect!
      expect(response.body).to include('AI処理中')
    end
  end

  describe 'dashboard presentation route' do
    before { sign_in client }

    it 'redirects to public conversation preview' do
      get presentation_dashboard_deal_path(deal)
      expect(response).to redirect_to(conversation_public_deal_session_path(token: deal.access_token, preview: 1))
    end
  end
end
