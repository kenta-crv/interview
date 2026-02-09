# app/services/interview_engine/tts_client.rb
module InterviewEngine
  class TTSClient
    require 'net/http'
    require 'json'
    require 'fileutils'

    OPENAI_API_KEY = ENV['OPENAI_API_KEY']
    OPENAI_URL = 'https://api.openai.com/v1/audio/speech'

    # Convert question text to speech
    def speak(text, language: 'en', voice: 'nova')
      raise "Text is empty" if text.blank?

      response = send_to_openai(text, language, voice)
      save_audio(response)
    rescue => e
      Rails.logger.error("TTS Error: #{e.message}")
      nil
    end

    private

    def send_to_openai(text, language, voice)
      uri = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{OPENAI_API_KEY}"
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

    def save_audio(response)
      if response.code == '200'
        filename = "question_#{Time.current.to_i}.mp3"
        filepath = Rails.root.join('tmp', 'interview_audio', filename)
        
        FileUtils.mkdir_p(filepath.dirname)
        File.binwrite(filepath, response.body)
        
        filepath.to_s
      else
        raise "TTS API Error: #{response.body}"
      end
    end
  end
end
