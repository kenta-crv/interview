require 'rails_helper'

RSpec.describe InterviewEngine::STTClient do
  let(:client) { described_class.new }

  describe '#transcribe' do
    let(:audio_path) { Rails.root.join('test_audio.wav').to_s }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')
      # テスト用音声ファイルが存在することを前提（プロジェクトに test_audio.wav がある）
    end

    context 'ファイルバリデーション' do
      it '存在しないファイルでSTTErrorを発生する' do
        expect {
          client.transcribe('/nonexistent/path/audio.wav')
        }.to raise_error(InterviewEngine::STTClient::STTError, /not found/)
      end

      it 'サポートされていない形式でSTTErrorを発生する' do
        tmpfile = Tempfile.new(['test', '.txt'])
        tmpfile.write('not audio')
        tmpfile.close

        expect {
          client.transcribe(tmpfile.path)
        }.to raise_error(InterviewEngine::STTClient::STTError, /Unsupported audio format/)
      ensure
        tmpfile&.unlink
      end

      it '空のファイルでSTTErrorを発生する' do
        tmpfile = Tempfile.new(['test', '.wav'])
        tmpfile.close

        expect {
          client.transcribe(tmpfile.path)
        }.to raise_error(InterviewEngine::STTClient::STTError, /empty/)
      ensure
        tmpfile&.unlink
      end

      it 'ファイルサイズ超過でSTTErrorを発生する' do
        tmpfile = Tempfile.new(['test', '.wav'])
        tmpfile.write('x')
        tmpfile.close

        max_size = Rails.application.config.interview.stt_max_file_size
        allow(File).to receive(:size).and_call_original
        allow(File).to receive(:size).with(tmpfile.path).and_return(max_size + 1)

        expect {
          client.transcribe(tmpfile.path)
        }.to raise_error(InterviewEngine::STTClient::STTError, /too large/)
      ensure
        tmpfile&.unlink
      end
    end

    context 'API呼び出し' do
      before do
        # test_audio.wav が存在することを確認
        skip 'test_audio.wav not found' unless File.exist?(audio_path)
      end

      it '正常なレスポンスからトランスクリプトを返す' do
        response_mock = instance_double(Net::HTTPResponse,
                                        code: '200',
                                        body: { 'text' => 'テスト回答です' }.to_json)
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)
        allow(http_mock).to receive(:open_timeout=)
        allow(http_mock).to receive(:read_timeout=)
        allow(http_mock).to receive(:request).and_return(response_mock)

        result = client.transcribe(audio_path, language: 'ja')
        expect(result).to eq('テスト回答です')
      end

      it '空のトランスクリプトでSTTErrorを発生する' do
        response_mock = instance_double(Net::HTTPResponse,
                                        code: '200',
                                        body: { 'text' => '' }.to_json)
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)
        allow(http_mock).to receive(:open_timeout=)
        allow(http_mock).to receive(:read_timeout=)
        allow(http_mock).to receive(:request).and_return(response_mock)

        expect {
          client.transcribe(audio_path)
        }.to raise_error(InterviewEngine::STTClient::STTError, /Empty transcript/)
      end

      it 'サーバーエラー(500)のリトライ後にSTTErrorを発生する' do
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
          client.transcribe(audio_path)
        }.to raise_error(InterviewEngine::STTClient::STTError)
      end

      it 'クライアントエラー(400)でSTTErrorを発生する' do
        response_mock = instance_double(Net::HTTPResponse,
                                        code: '400',
                                        body: { 'error' => { 'message' => 'Bad request' } }.to_json)
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)
        allow(http_mock).to receive(:open_timeout=)
        allow(http_mock).to receive(:read_timeout=)
        allow(http_mock).to receive(:request).and_return(response_mock)

        expect {
          client.transcribe(audio_path)
        }.to raise_error(InterviewEngine::STTClient::STTError, /Bad request/)
      end
    end

    context 'APIキー' do
      it 'OPENAI_API_KEY未設定でSTTErrorを発生する' do
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
        skip 'test_audio.wav not found' unless File.exist?(audio_path)

        expect {
          client.transcribe(audio_path)
        }.to raise_error(InterviewEngine::STTClient::STTError, /OPENAI_API_KEY/)
      end
    end

    context '言語正規化' do
      it 'jaをそのまま返す' do
        normalized = client.send(:normalize_language, 'ja')
        expect(normalized).to eq('ja')
      end

      it 'enをそのまま返す' do
        normalized = client.send(:normalize_language, 'en')
        expect(normalized).to eq('en')
      end

      it '未知の言語はenにフォールバックする' do
        normalized = client.send(:normalize_language, 'fr')
        expect(normalized).to eq('en')
      end
    end
  end
end
