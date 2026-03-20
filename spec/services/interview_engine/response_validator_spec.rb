require 'rails_helper'

RSpec.describe InterviewEngine::ResponseValidator do
  describe '.extract_json' do
    it '有効なJSONをパースする' do
      json = '{"relevance_score": 80, "passed": true}'
      result = described_class.extract_json(json)

      expect(result).to be_a(HashWithIndifferentAccess)
      expect(result[:relevance_score]).to eq(80)
    end

    it 'コードブロック内のJSONを抽出する' do
      text = "```json\n{\"relevance_score\": 85}\n```"
      result = described_class.extract_json(text)

      expect(result[:relevance_score]).to eq(85)
    end

    it 'テキスト中のJSON部分を抽出する' do
      text = "Here is the result: {\"relevance_score\": 90} done."
      result = described_class.extract_json(text)

      expect(result[:relevance_score]).to eq(90)
    end

    it '空文字列はnilを返す' do
      expect(described_class.extract_json('')).to be_nil
    end

    it 'nilはnilを返す' do
      expect(described_class.extract_json(nil)).to be_nil
    end

    it '無効なJSONはnilを返す' do
      expect(described_class.extract_json('not json at all')).to be_nil
    end
  end

  describe '.validate_evaluation!' do
    let(:valid_data) do
      {
        'relevance_score' => 85,
        'correctness_score' => 80,
        'clarity_score' => 90,
        'final_score' => 85,
        'passed' => true,
        'reasoning' => '良い回答'
      }.with_indifferent_access
    end

    it '有効なデータをそのまま返す' do
      result = described_class.validate_evaluation!(valid_data)
      expect(result[:relevance_score]).to eq(85)
    end

    it '必須キーが欠けている場合はエラーを発生する' do
      valid_data.delete('reasoning')

      expect {
        described_class.validate_evaluation!(valid_data)
      }.to raise_error(InterviewEngine::ResponseValidator::InvalidResponseError, /Missing required keys/)
    end

    it 'Hash以外の入力でエラーを発生する' do
      expect {
        described_class.validate_evaluation!('not a hash')
      }.to raise_error(InterviewEngine::ResponseValidator::InvalidResponseError, /must be a Hash/)
    end

    it 'スコアを0-100にクランプする' do
      valid_data['relevance_score'] = 150
      valid_data['correctness_score'] = -10

      result = described_class.validate_evaluation!(valid_data)
      expect(result['relevance_score']).to eq(100)
      expect(result['correctness_score']).to eq(0)
    end

    it 'passed文字列をbooleanに変換する' do
      valid_data['passed'] = 'true'
      result = described_class.validate_evaluation!(valid_data)
      expect(result['passed']).to be true

      valid_data['passed'] = 'false'
      result = described_class.validate_evaluation!(valid_data)
      expect(result['passed']).to be false
    end
  end

  describe '.validate_summary!' do
    let(:valid_data) do
      {
        'summary' => 'テスト要約',
        'strengths' => ['強み1', '強み2'],
        'weaknesses' => ['弱み1'],
        'recommendation' => '採用推奨'
      }.with_indifferent_access
    end

    it '有効なデータをそのまま返す' do
      result = described_class.validate_summary!(valid_data)
      expect(result[:summary]).to eq('テスト要約')
    end

    it '必須キーが欠けている場合はエラーを発生する' do
      valid_data.delete('recommendation')

      expect {
        described_class.validate_summary!(valid_data)
      }.to raise_error(InterviewEngine::ResponseValidator::InvalidResponseError)
    end

    it '配列項目数を制限する' do
      valid_data['strengths'] = Array.new(10) { |i| "強み#{i}" }
      result = described_class.validate_summary!(valid_data)
      expect(result['strengths'].length).to be <= 5
    end

    it '配列でない値を空配列に変換する' do
      valid_data['strengths'] = 'not an array'
      result = described_class.validate_summary!(valid_data)
      expect(result['strengths']).to eq([])
    end
  end
end
