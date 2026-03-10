# app/services/interview_engine/tts_client.rb
require 'net/http'
require 'json'
require 'fileutils'

module InterviewEngine
  class TTSClient
    class TTSError < StandardError; end
    class TTSTimeoutError < TTSError; end

    OPENAI_URL = 'https://api.openai.com/v1/audio/speech'.freeze
    MAX_TEXT_LENGTH = 4096 # OpenAI TTS 入力上限
    MAX_RETRIES = 2
    RETRY_DELAY_BASE = 1
    TIMEOUT_SECONDS = 30

    # 言語ごとの推奨ボイス
    VOICE_MAP = {
      'ja' => 'nova',
      'en' => 'nova'
    }.freeze

    DEFAULT_VOICE = 'nova'.freeze

    # Convert question text to speech, returns file path
    def speak(text, language: 'en', voice: nil)
      raise TTSError, "Text is empty" if text.blank?

      text = text.truncate(MAX_TEXT_LENGTH)
      voice ||= VOICE_MAP[language.to_s] || DEFAULT_VOICE

      audio_path = nil
      retries = 0

      begin
        response = send_to_openai(text, voice)
        audio_path = handle_response(response)
      rescue TTSTimeoutError, Net::OpenTimeout, Net::ReadTimeout => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep(RETRY_DELAY_BASE * retries)
          retry
        end
        Rails.logger.error("TTS timeout after #{MAX_RETRIES} retries: #{e.message}")
        raise TTSError, "Speech generation timed out"
      end

      audio_path
    end

    private

    def send_to_openai(text, voice)
      uri = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT_SECONDS
      http.read_timeout = TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'

      body = {
        model: 'tts-1',
        input: text,
        voice: voice,
        response_format: 'mp3'
      }

      request.body = body.to_json
      http.request(request)
    end

    def handle_response(response)
      case response.code.to_i
      when 200
        save_audio(response.body)
      when 429
        raise TTSTimeoutError, "Rate limit exceeded"
      when 400..499
        parsed = JSON.parse(response.body) rescue {}
        raise TTSError, "TTS API error (#{response.code}): #{parsed['error']&.dig('message') || response.body.truncate(200)}"
      when 500..599
        raise TTSTimeoutError, "TTS API server error (#{response.code})"
      else
        raise TTSError, "Unexpected response (#{response.code})"
      end
    end

    def save_audio(audio_data)
      raise TTSError, "Empty audio response" if audio_data.blank?

      filename = "question_#{SecureRandom.hex(8)}.mp3"
      dir = Rails.root.join('tmp', 'interview_audio')
      FileUtils.mkdir_p(dir)

      filepath = dir.join(filename)
      File.binwrite(filepath, audio_data)

      filepath.to_s
    end

    def api_key
      ENV['OPENAI_API_KEY'] || raise(TTSError, "OPENAI_API_KEY is not set")
    end
  end
end
