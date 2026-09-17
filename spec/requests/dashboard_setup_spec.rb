require "rails_helper"

RSpec.describe "Dashboard first-time setup", type: :request do
  let(:client) { create(:client) }

  before { sign_in client }

  it "未公開のクライアントはダッシュボードから初回案内へ送る" do
    get dashboard_index_path

    expect(response).to redirect_to(dashboard_setup_path)
    follow_redirect!
    expect(response.body).to include("最初の3ステップ")
    expect(response.body).to include("商談を新規作成")
    expect(response.body).to include("手元にPDFがなくても")
    expect(response.body).to include(new_dashboard_deal_path)
    expect(response.body).not_to include("URLアクセス")
  end

  it "公開済み商談があるときは成果ダッシュボードを出す" do
    Deal.create!(
      client: client,
      title: "公開済み商談",
      language: "ja",
      status: :completed,
      playback_ready: true
    )

    get dashboard_index_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("URLアクセス")
    expect(response.body).to include("公開済み商談")
  end

  it "未公開商談の詳細では次にやることを出す" do
    deal = Deal.create!(
      client: client,
      title: "下書き商談",
      language: "ja",
      status: :uploading,
      playback_ready: false
    )

    get dashboard_deal_path(deal)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("次にやること")
    expect(response.body).to include("最初のPDFをアップロードしてください")
  end
end
