require 'rails_helper'

RSpec.describe InterviewEngine::PromptTemplate do
  describe '.evaluation' do
    it '日本語の評価プロンプトを返す' do
      result = described_class.evaluation(
        question_text: 'テスト質問',
        user_answer: 'テスト回答',
        language: 'ja'
      )

      expect(result).to have_key(:system)
      expect(result).to have_key(:user)
      expect(result[:system]).to include('面接評価者')
      expect(result[:user]).to include('テスト質問')
      expect(result[:user]).to include('テスト回答')
    end

    it '英語の評価プロンプトを返す' do
      result = described_class.evaluation(
        question_text: 'Test question',
        user_answer: 'Test answer',
        language: 'en'
      )

      expect(result[:system]).to include('interview evaluator')
      expect(result[:user]).to include('Test question')
    end

    it '未知の言語は英語にフォールバックする' do
      result = described_class.evaluation(
        question_text: 'Test',
        user_answer: 'Answer',
        language: 'fr'
      )

      expect(result[:system]).to include('interview evaluator')
    end

    it 'ユーザー入力をサニタイズする' do
      result = described_class.evaluation(
        question_text: '```inject```',
        user_answer: 'test',
        language: 'en'
      )

      # バッククォートが置換される
      expect(result[:user]).not_to include('```')
      expect(result[:user]).to include('BEGIN USER INPUT')
    end
  end

  describe '.summary' do
    it '日本語のサマリープロンプトを返す' do
      result = described_class.summary(
        responses_data: [{ question: 'Q1', answer: 'A1', score: 80 }],
        language: 'ja'
      )

      expect(result[:system]).to include('サマリー')
      expect(result[:user]).to include('Q1')
    end

    it '英語のサマリープロンプトを返す' do
      result = described_class.summary(
        responses_data: [{ question: 'Q1', answer: 'A1', score: 80 }],
        language: 'en'
      )

      expect(result[:system]).to include('summarizer')
    end

    it '空のデータでArgumentErrorを発生する' do
      expect {
        described_class.summary(responses_data: [])
      }.to raise_error(ArgumentError, /must not be empty/)
    end
  end

  describe '.expected_schema' do
    it '評価スキーマを返す' do
      schema = described_class.expected_schema(:evaluation)

      expect(schema[:required_keys]).to include('relevance_score', 'passed', 'reasoning')
      expect(schema[:score_keys]).to include('relevance_score')
      expect(schema[:score_range]).to eq(0..100)
    end

    it 'サマリースキーマを返す' do
      schema = described_class.expected_schema(:summary)

      expect(schema[:required_keys]).to include('summary', 'strengths')
      expect(schema[:array_keys]).to include('strengths', 'weaknesses')
    end

    it '不明なタイプでArgumentErrorを発生する' do
      expect {
        described_class.expected_schema(:unknown)
      }.to raise_error(ArgumentError, /Unknown schema type/)
    end
  end
end
