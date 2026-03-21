require 'rails_helper'

RSpec.describe InterviewEngine::TTSClient do
  let(:client) { described_class.new }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')
  end

  describe '#speak' do
    it '正常なレスポンスで音声ファイルパスを返す' do
      audio_data = 'fake_audio_binary_data'
      response_mock = instance_double(Net::HTTPResponse,
                                      code: '200',
                                      body: audio_data)
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)
      allow(http_mock).to receive(:request).and_return(response_mock)

      result = client.speak('テスト質問です', language: 'ja')

      expect(result).to be_a(String)
      expect(File.exist?(result)).to be true
      expect(File.read(result)).to eq(audio_data)

      # クリーンアップ
      File.delete(result) if File.exist?(result)
    end

    it '空のテキストでTTSErrorを発生する' do
      expect {
        client.speak('')
      }.to raise_error(InterviewEngine::TTSClient::TTSError, /empty/)
    end

    it 'nilのテキストでTTSErrorを発生する' do
      expect {
        client.speak(nil)
      }.to raise_error(InterviewEngine::TTSClient::TTSError, /empty/)
    end

    it 'OPENAI_API_KEY未設定でTTSErrorを発生する' do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)

      expect {
        client.speak('テスト')
      }.to raise_error(InterviewEngine::TTSClient::TTSError, /OPENAI_API_KEY/)
    end

    it 'レート制限(429)のリトライ後にTTSErrorを発生する' do
      response_mock = instance_double(Net::HTTPResponse,
                                      code: '429',
                                      body: '{}')
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)
      allow(http_mock).to receive(:request).and_return(response_mock)
      allow(client).to receive(:sleep)

      expect {
        client.speak('テスト')
      }.to raise_error(InterviewEngine::TTSClient::TTSError)
    end

    it 'サーバーエラー(500)のリトライ後にTTSErrorを発生する' do
      response_mock = instance_double(Net::HTTPResponse,
                                      code: '500',
                                      body: '{}')
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)
      allow(http_mock).to receive(:request).and_return(response_mock)
      allow(client).to receive(:sleep)

      expect {
        client.speak('テスト')
      }.to raise_error(InterviewEngine::TTSClient::TTSError)
    end

    it 'クライアントエラー(400)でTTSErrorを発生する' do
      response_mock = instance_double(Net::HTTPResponse,
                                      code: '400',
                                      body: { 'error' => { 'message' => 'Invalid voice' } }.to_json)
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)
      allow(http_mock).to receive(:request).and_return(response_mock)

      expect {
        client.speak('テスト')
      }.to raise_error(InterviewEngine::TTSClient::TTSError, /Invalid voice/)
    end

    it '空の音声レスポンスでTTSErrorを発生する' do
      response_mock = instance_double(Net::HTTPResponse,
                                      code: '200',
                                      body: '')
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)
      allow(http_mock).to receive(:open_timeout=)
      allow(http_mock).to receive(:read_timeout=)
      allow(http_mock).to receive(:request).and_return(response_mock)

      expect {
        client.speak('テスト')
      }.to raise_error(InterviewEngine::TTSClient::TTSError, /Empty audio/)
    end
  end

  describe '言語別ボイス選択' do
    it '日本語の場合はtts_voice_jaを使用する' do
      voice = client.send(:voice_for_language, 'ja')
      expect(voice).to eq(Rails.application.config.interview.tts_voice_ja)
    end

    it '英語の場合はtts_voice_enを使用する' do
      voice = client.send(:voice_for_language, 'en')
      expect(voice).to eq(Rails.application.config.interview.tts_voice_en)
    end

    it '未知の言語はデフォルトボイスを使用する' do
      voice = client.send(:voice_for_language, 'fr')
      expect(voice).to eq(Rails.application.config.interview.tts_default_voice)
    end
  end
end
