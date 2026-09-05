require 'rails_helper'

RSpec.describe Client, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:situations) }
  end

  describe 'validations' do
    it 'requires email' do
      client = build(:client, email: '')
      expect(client).not_to be_valid
      expect(client.errors[:email]).to be_present
    end

    it 'requires unique email' do
      create(:client, email: 'client@example.com')
      client = build(:client, email: 'client@example.com')
      expect(client).not_to be_valid
      expect(client.errors[:email]).to be_present
    end

    it 'requires valid email format' do
      client = build(:client, email: 'not-an-email')
      expect(client).not_to be_valid
    end

    it 'requires password with minimum length' do
      client = build(:client, password: 'short')
      expect(client).not_to be_valid
      expect(client.errors[:password]).to be_present
    end

    it 'creates with valid attributes' do
      client = build(:client)
      expect(client).to be_valid
    end
  end

  describe 'Devise modules' do
    it 'includes expected modules' do
      expected_modules = [:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable]
      expected_modules.each do |mod|
        expect(Client.devise_modules).to include(mod)
      end
    end
  end

  describe 'situations association' do
    it 'can have multiple situations' do
      client = create(:client)
      situation1 = create(:situation, client: client, title: 'シナリオ1')
      situation2 = create(:situation, client: client, title: 'シナリオ2')

      expect(client.situations).to include(situation1, situation2)
      expect(client.situations.count).to eq(2)
    end
  end

  describe '#intro_discount_eligible?' do
    it 'is true during trial before a paid plan' do
      client = create(:client)
      expect(client).to be_intro_discount_eligible
    end

    it 'is false after any paid plan exists' do
      client = create(:client)
      client.subscriptions.create!(plan_type: :standard, status: :cancelled)
      expect(client).not_to be_intro_discount_eligible
    end
  end

  describe '#trial_start_available?' do
    it 'is false once a trial subscription exists' do
      client = create(:client)
      expect(client).not_to be_trial_start_available
    end
  end
end

RSpec.describe "Yahoo Ads trial conversion", type: :request do
  let(:conv_label) { "ZJV84DQ0OVHBSHWU0P1364033" }

  it "新規登録直後のダッシュボードでYAds CVタグを1回出す" do
    email = "trial-cv-#{SecureRandom.hex(4)}@example.com"
    post client_registration_path, params: {
      client: {
        email: email,
        password: "password123",
        password_confirmation: "password123"
      }
    }

    expect(response).to redirect_to(dashboard_index_path)
    follow_redirect!
    expect(response.body).to include(conv_label)
    expect(response.body).to include("yjad_conversion")
    expect(response.body).to include("AW-10998015402")
    expect(response.body).to include("gtag/js?id=AW-10998015402")
    expect(response.body).to include("AW-10998015402/vlLmCJa_1OccEKrLofwo")
    expect(response.body).to include("gtag('event', 'conversion'")

    get dashboard_index_path
    expect(response.body).not_to include(conv_label)
    expect(response.body).not_to include("vlLmCJa_1OccEKrLofwo")
  end

  it "既存ログインではYAds CVタグを出さない" do
    client = create(:client)
    sign_in client
    get dashboard_index_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(conv_label)
    expect(response.body).not_to include("vlLmCJa_1OccEKrLofwo")
  end
end

RSpec.describe "Google Ads consent mode", type: :request do
  it "Consent Mode default とカスタムバナー用スクリプトを出す" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('gtag("consent", "default"')
    expect(response.body).to include("gtag('config', 'G-YCZ141VD12')")
    expect(response.body).to include("meetia-consent-banner")
    expect(response.body).to include("meetia_ads_consent")
    expect(response.body).to include("isTagAssistantDebug")
    expect(response.body).to include('name="meetia-visitor-country"')
    expect(response.body).to include('name="meetia-consent-regions"')
    expect(response.body).to include('content="AT,BE,BG')
    expect(response.body).not_to match(/region:\s*\[&quot;/)
  end

  it "Cloudflare 国ヘッダーを meta に載せる" do
    get root_path, headers: { "CF-IPCountry" => "DE" }
    expect(response.body).to include('content="DE"')
  end

  it "Tag Assistant 用に frame-ancestors を許可し X-Frame-Options を外す" do
    get root_path
    expect(response).to have_http_status(:ok)
    csp = response.headers["Content-Security-Policy"].to_s
    expect(csp).to include("frame-ancestors")
    expect(csp).to include("tagassistant.google.com")
    expect(response.headers["X-Frame-Options"]).to be_blank
  end
end
