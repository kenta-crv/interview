require 'rails_helper'

RSpec.describe InterviewEngine::LLMClient do
  let(:client) { described_class.new }

  describe '#evaluate_response' do
    let(:question_text) { 'あなたの経験を教えてください' }
    let(:user_answer) { '5年間のRails開発経験があります' }

    context 'OpenAIモデル' do
      before do
        allow(Rails.application.config.interview).to receive(:llm_model).and_return('openai')
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')
      end

      it '正常なレスポンスを返す' do
        valid_json = {
          relevance_score: 85,
          correctness_score: 80,
          clarity_score: 90,
          final_score: 85,
          passed: true,
          reasoning: '良い回答'
        }.to_json

        stub_openai_response(valid_json)

        result = client.evaluate_response(question_text, user_answer, language: 'ja')

        expect(result[:relevance_score]).to eq(85)
        expect(result[:passed]).to be true
      end

      it 'APIキーが未設定の場合はデフォルトエラーレスポンスを返す' do
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)

        result = client.evaluate_response(question_text, user_answer)

        expect(result[:relevance_score]).to eq(0)
        expect(result[:passed]).to be false
        expect(result[:reasoning]).to include('failed')
      end

      it 'タイムアウト時にデフォルトエラーレスポンスを返す' do
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)
        allow(http_mock).to receive(:open_timeout=)
        allow(http_mock).to receive(:read_timeout=)
        allow(http_mock).to receive(:request).and_raise(Net::ReadTimeout)

        result = client.evaluate_response(question_text, user_answer)

        expect(result[:relevance_score]).to eq(0)
        expect(result[:passed]).to be false
      end

      it 'レート制限エラー(429)時にリトライしてデフォルトレスポンスを返す' do
        response_mock = instance_double(Net::HTTPResponse, code: '429', body: '{}')
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)
        allow(http_mock).to receive(:open_timeout=)
        allow(http_mock).to receive(:read_timeout=)
        allow(http_mock).to receive(:request).and_return(response_mock)
        # sleep をスキップ
        allow(client).to receive(:sleep)

        result = client.evaluate_response(question_text, user_answer)

        expect(result[:relevance_score]).to eq(0)
      end

      it '認証エラー(401)時にデフォルトレスポンスを返す' do
        response_mock = instance_double(Net::HTTPResponse, code: '401', body: '{}')
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)
        allow(http_mock).to receive(:open_timeout=)
        allow(http_mock).to receive(:read_timeout=)
        allow(http_mock).to receive(:request).and_return(response_mock)

        result = client.evaluate_response(question_text, user_answer)

        expect(result[:relevance_score]).to eq(0)
      end
    end

    context 'Claudeモデル' do
      let(:claude_client) { described_class.new(model: 'claude') }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return('test-claude-key')
      end

      it 'Claude APIを呼び出す' do
        valid_json = {
          relevance_score: 90,
          correctness_score: 85,
          clarity_score: 88,
          final_score: 88,
          passed: true,
          reasoning: '素晴らしい回答'
        }.to_json

        stub_claude_response(valid_json)

        result = claude_client.evaluate_response(question_text, user_answer, language: 'ja')
        expect(result[:relevance_score]).to eq(90)
      end

      it 'CLAUDE_API_KEY未設定時にデフォルトレスポンスを返す' do
        allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return(nil)

        result = claude_client.evaluate_response(question_text, user_answer)
        expect(result[:relevance_score]).to eq(0)
      end
    end

    context '不明なモデル' do
      let(:unknown_client) { described_class.new(model: 'unknown') }

      it 'デフォルトエラーレスポンスを返す' do
        result = unknown_client.evaluate_response(question_text, user_answer)
        expect(result[:relevance_score]).to eq(0)
      end
    end
  end

  describe '#summarize_interview' do
    let(:responses) do
      situation = create(:situation, :with_questions, client: create(:client))
      interview = create(:interview, :in_progress, user: create(:user), situation: situation)
      situation.questions.map do |q|
        create(:interview_response, :evaluated, interview: interview, question: q)
      end
    end

    before do
      allow(Rails.application.config.interview).to receive(:llm_model).and_return('openai')
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')
    end

    it '正常なサマリーを返す' do
      valid_json = {
        summary: '候補者は全般的に良好',
        strengths: ['技術力', 'コミュニケーション'],
        weaknesses: ['経験不足'],
        recommendation: '採用推奨'
      }.to_json

      stub_openai_response(valid_json)

      result = client.summarize_interview(responses, language: 'ja')

      expect(result[:summary]).to eq('候補者は全般的に良好')
      expect(result[:strengths]).to be_an(Array)
      expect(result[:recommendation]).to eq('採用推奨')
    end

    it 'API失敗時にデフォルトサマリーを返す' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)

      result = client.summarize_interview(responses)

      expect(result[:summary]).to eq('Summary unavailable')
      expect(result[:recommendation]).to eq('Review required')
    end
  end

  private

  def stub_openai_response(json_body)
    openai_response = {
      'choices' => [
        { 'message' => { 'content' => json_body } }
      ]
    }
    response_mock = instance_double(Net::HTTPResponse,
                                    code: '200',
                                    body: openai_response.to_json)
    http_mock = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http_mock)
    allow(http_mock).to receive(:use_ssl=)
    allow(http_mock).to receive(:open_timeout=)
    allow(http_mock).to receive(:read_timeout=)
    allow(http_mock).to receive(:request).and_return(response_mock)
  end

  def stub_claude_response(json_body)
    claude_response = {
      'content' => [
        { 'text' => json_body }
      ]
    }
    response_mock = instance_double(Net::HTTPResponse,
                                    code: '200',
                                    body: claude_response.to_json)
    http_mock = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http_mock)
    allow(http_mock).to receive(:use_ssl=)
    allow(http_mock).to receive(:open_timeout=)
    allow(http_mock).to receive(:read_timeout=)
    allow(http_mock).to receive(:request).and_return(response_mock)
  end
end
