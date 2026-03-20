# app/services/interview_engine/tts_client.rb
require 'net/http'
require 'json'
require 'fileutils'

module InterviewEngine
  class TTSClient
    class TTSError < StandardError; end
    class TTSTimeoutError < TTSError; end

    OPENAI_URL = 'https://api.openai.com/v1/audio/speech'.freeze
    RETRY_DELAY_BASE = 1

    # Convert question text to speech, returns file path
    def speak(text, language: 'en', voice: nil)
      raise TTSError, "Text is empty" if text.blank?

      text = text.truncate(config.tts_max_text_length)
      voice ||= voice_for_language(language)

      audio_path = nil
      retries = 0

      begin
        response = send_to_openai(text, voice)
        audio_path = handle_response(response)
      rescue TTSTimeoutError, Net::OpenTimeout, Net::ReadTimeout => e
        retries += 1
        if retries <= config.tts_max_retries
          sleep(RETRY_DELAY_BASE * retries)
          retry
        end
        Rails.logger.error("TTS timeout after #{config.tts_max_retries} retries: #{e.message}")
        raise TTSError, "Speech generation timed out"
      end

      audio_path
    end

    private

    def send_to_openai(text, voice)
      uri = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = config.tts_timeout
      http.read_timeout = config.tts_timeout

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'

      body = {
        model: config.tts_model,
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

    def voice_for_language(language)
      case language.to_s
      when 'ja' then config.tts_voice_ja
      when 'en' then config.tts_voice_en
      else config.tts_default_voice
      end
    end

    def config
      Rails.application.config.interview
    end
  end
end
