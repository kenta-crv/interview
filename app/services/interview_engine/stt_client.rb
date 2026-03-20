# app/services/interview_engine/stt_client.rb
require 'net/http'
require 'json'

module InterviewEngine
  class STTClient
    class STTError < StandardError; end
    class STTTimeoutError < STTError; end

    OPENAI_URL = 'https://api.openai.com/v1/audio/transcriptions'.freeze
    ALLOWED_FORMATS = %w[.mp3 .mp4 .mpeg .mpga .m4a .wav .webm].freeze
    RETRY_DELAY_BASE = 1

    # Convert audio file to text transcript
    def transcribe(audio_file_path, language: 'en')
      validate_file!(audio_file_path)

      transcript = nil
      retries = 0

      begin
        response = send_to_openai(audio_file_path, language)
        transcript = handle_response(response)
      rescue STTTimeoutError, Net::OpenTimeout, Net::ReadTimeout => e
        retries += 1
        if retries <= config.stt_max_retries
          sleep(RETRY_DELAY_BASE * retries)
          retry
        end
        Rails.logger.error("STT timeout after #{config.stt_max_retries} retries: #{e.message}")
        raise STTError, "Transcription timed out"
      end

      transcript
    end

    private

    def validate_file!(path)
      raise STTError, "Audio file not found: #{path}" unless File.exist?(path)

      max_size = config.stt_max_file_size
      size = File.size(path)
      raise STTError, "Audio file too large (#{(size / 1024.0 / 1024).round(1)}MB, max #{max_size / 1024 / 1024}MB)" if size > max_size
      raise STTError, "Audio file is empty" if size.zero?

      ext = File.extname(path).downcase
      unless ALLOWED_FORMATS.include?(ext)
        raise STTError, "Unsupported audio format: #{ext} (allowed: #{ALLOWED_FORMATS.join(', ')})"
      end
    end

    def send_to_openai(audio_file_path, language)
      uri = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = config.stt_timeout
      http.read_timeout = config.stt_timeout

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_key}"

      File.open(audio_file_path, 'rb') do |file|
        form_data = [
          ['file', file],
          ['model', config.stt_model],
          ['language', normalize_language(language)],
          ['response_format', 'json']
        ]

        request.set_form(form_data, 'multipart/form-data')
        http.request(request)
      end
    end

    def handle_response(response)
      case response.code.to_i
      when 200
        parsed = JSON.parse(response.body)
        text = parsed['text']&.strip
        raise STTError, "Empty transcript returned" if text.blank?
        text
      when 429
        # 429もリトライ対象: STTTimeoutError として上位の retry ロジックでリトライされる
        raise STTTimeoutError, "Rate limit exceeded"
      when 400..499
        parsed = JSON.parse(response.body) rescue {}
        raise STTError, "Whisper API error (#{response.code}): #{parsed['error']&.dig('message') || response.body.truncate(200)}"
      when 500..599
        raise STTTimeoutError, "Whisper API server error (#{response.code})"
      else
        raise STTError, "Unexpected response (#{response.code})"
      end
    end

    def normalize_language(language)
      case language.to_s
      when 'ja' then 'ja'
      when 'en' then 'en'
      else 'en'
      end
    end

    def api_key
      ENV['OPENAI_API_KEY'] || raise(STTError, "OPENAI_API_KEY is not set")
    end

    def config
      Rails.application.config.interview
    end
  end
end
