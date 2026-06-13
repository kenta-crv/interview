# app/services/deal_engine/tts_service.rb
require 'openai'

module DealEngine
  class TTSService
    OPENAI_TTS_URL = 'https://api.openai.com/v1/audio/speech'

    def initialize(text:, voice: 'alloy', language: 'en')
      @text = text
      @voice = voice
      @language = language
    end

    def generate_speech
      api_key = ENV['OPENAI_API_KEY']
      raise 'OPENAI_API_KEY is not set' if api_key.blank?

      client = OpenAI::Client.new(access_token: api_key)

      response = client.audio.speech(
        parameters: {
          model: 'tts-1',
          input: @text,
          voice: @voice
        }
      )

      response
    rescue OpenAI::Error => e
      Rails.logger.error("OpenAI TTS Error: #{e.message}")
      raise
    end

    def self.generate_from_deal_summary(deal)
      return nil unless deal.deal_summary.present?

      # 要約から読み上げテキストを生成
      text = build_speech_text(deal)

      # 言語に応じて音声を選択
      voice = deal.language == 'ja' ? 'alloy' : 'alloy'

      new(text: text, voice: voice, language: deal.language).generate_speech
    end

    def self.build_speech_text(deal)
      summary = deal.deal_summary

      if deal.language == 'ja'
        <<~TEXT
          #{summary.summary}
          重要なポイントは以下の通りです。
          #{summary.key_points}
          アクションアイテムは以下の通りです。
          #{summary.action_items}
          次のステップは以下の通りです。
          #{summary.next_steps}
        TEXT
      else
        <<~TEXT
          #{summary.summary}
          Here are the key points.
          #{summary.key_points}
          Here are the action items.
          #{summary.action_items}
          Here are the next steps.
          #{summary.next_steps}
        TEXT
      end
    end
  end
end
