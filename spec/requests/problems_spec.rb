require "rails_helper"

RSpec.describe "Problems", type: :request do
  before do
    allow(ProblemMailer).to receive_message_chain(:report_email, :deliver)
  end

  describe "GET /problems/new" do
    it "ダッシュボード向けレイアウトで表示する" do
      get new_problem_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("問題報告")
      expect(response.body).to include("報告を送信する")
    end

    it "embed=1 のとき埋め込み用レイアウトで表示する" do
      get new_problem_path(embed: 1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("db-v2-problem-embed")
      expect(response.body).to include('name="embed"')
    end
  end

  describe "POST /problems" do
    let(:valid_params) do
      {
        problem: {
          company: "株式会社テスト",
          email: "report@example.com",
          body: "画面が表示されません"
        }
      }
    end

    it "送信後にダッシュボードへリダイレクトし完了通知を出す" do
      expect {
        post problems_path, params: valid_params
      }.to change(Problem, :count).by(1)

      expect(response).to redirect_to(dashboard_index_path)
      expect(flash[:notice]).to eq("報告完了しました")
    end

    it "embed 送信時は親ウィンドウ向けの完了ページを返す" do
      post problems_path, params: valid_params.merge(embed: "1")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("報告完了しました")
      expect(response.body).to include(dashboard_index_path)
      expect(flash[:notice]).to eq("報告完了しました")
    end
  end
end
