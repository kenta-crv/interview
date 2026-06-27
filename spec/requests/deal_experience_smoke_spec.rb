require 'rails_helper'

RSpec.describe 'Deal experience smoke', type: :request do
  let(:client) do
    Client.create!(
      email: "client_#{SecureRandom.hex(4)}@example.com",
      password: 'password123'
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

  before do
    deal.update!(
      greeting_script: 'こんにちは。AI商談を開始します。',
      company_overview_script: '当社はAI商談支援を提供しています。',
      usage_guide_script: 'ボタンまたは自由質問で進行できます。'
    )
  end

  describe 'public conversation flow' do
    it 'shows opening messages and responds to topic' do
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
      expect(response.body).to include('こんにちは。AI商談を開始します。')
      expect(response.body).to include('知りたいトピックを選択')
      expect(response.body).to include('data-deal-conversation')
      expect(response.body).to include('deal_conversation')
      expect(response.body).to include('deal-public-body')
      expect(response.body).not_to include('custom-navbar')

      post respond_public_deal_session_path(token: deal.access_token), params: {
        topic: 'overview',
        page_number: 1
      }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['text']).to be_present
      expect(payload['type']).to be_in(%w[page ai])
    end
  end

  describe 'dashboard deal reprocess' do
    before do
      sign_in client
      doc = deal.deal_documents.create!(filename: 'test.pdf', content_type: 'application/pdf')
      doc.file.attach(
        io: StringIO.new('%PDF-1.4 test'),
        filename: 'test.pdf',
        content_type: 'application/pdf'
      )
    end

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

  describe 'dashboard presentation view' do
    before do
      sign_in client
      doc = deal.deal_documents.create!(filename: 'test.pdf', content_type: 'application/pdf')
      doc.file.attach(
        io: StringIO.new('%PDF-1.4 test'),
        filename: 'test.pdf',
        content_type: 'application/pdf'
      )
      deal.deal_pages.create!(
        deal_document: doc,
        page_number: 1,
        title: '表紙・ご挨拶',
        script: 'ご挨拶です'
      )
      deal.deal_pages.create!(
        deal_document: doc,
        page_number: 2,
        title: '会社概要',
        script: '会社概要です'
      )
    end

    it 'renders presentation structure and choice controls' do
      get presentation_dashboard_deal_path(deal)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('presentation-wrapper')
      expect(response.body).to include('presentation-left')
      expect(response.body).to include('choice-buttons')
      expect(response.body).to include('btn-choice')
      expect(response.body).to include('deal-presentation-config')
      expect(response.body).to include('presentation-start-overlay')
      expect(response.body).to include('AI商談を開始')
      expect(response.body).to include('meetia_page_init')
      expect(response.body).to include('deal_presentation')
      expect(response.body).to include('presentation-body')
      expect(response.body).not_to include('guidance-text')
      expect(response.body).not_to include('custom-navbar')
      expect(response.body).to include('#page=')
    end
  end
end
