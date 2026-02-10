# app/services/interview_engine/stt_client.rb
module InterviewEngine
  class STTClient
    require 'net/http'
    require 'json'

    OPENAI_API_KEY = ENV['OPENAI_API_KEY']
    OPENAI_URL = 'https://api.openai.com/v1/audio/transcriptions'

    # Convert audio file to text transcript
    def transcribe(audio_file_path, language: 'en')
      raise "Audio file not found: #{audio_file_path}" unless File.exist?(audio_file_path)
      
      response = send_to_openai(audio_file_path, language)
      extract_transcript(response)
    rescue => e
      Rails.logger.error("STT Error: #{e.message}")
      nil
    end

    private

    def send_to_openai(audio_file_path, language)
      uri = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{OPENAI_API_KEY}"

      form_data = [
        ['file', File.new(audio_file_path, 'rb')],
        ['model', 'whisper-1'],
        ['language', language_code(language)]
      ]

      request.set_form form_data, 'multipart/form-data'
      http.request(request)
    end

    def extract_transcript(response)
      parsed = JSON.parse(response.body)
      
      if parsed['text']
        parsed['text'].strip
      else
        raise "Invalid Whisper response"
      end
    end

    def language_code(language)
      case language
      when 'ja' then 'ja'
      when 'en' then 'en'
      else 'en'
      end
    end
  end
end
