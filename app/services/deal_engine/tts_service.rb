# app/services/deal_engine/tts_service.rb
require 'openai'

module DealEngine
  class TTSService
    MODEL = 'gpt-4o-mini-tts'.freeze

    FEMALE_INSTRUCTIONS_JA = <<~TEXT.freeze
      You are the Meetia AI sales avatar: a gentle Japanese woman around 22-25.
      Soft smile, warm, helpful. Clearly feminine soft bright voice. Natural Tokyo Japanese.
      Polite modern AI host. Never male, deep, or stern.
    TEXT

    MALE_INSTRUCTIONS_JA = <<~TEXT.freeze
      You are a Meetia AI sales avatar: a calm Japanese man around late 20s.
      Voice must be clearly masculine but approachable. Natural Tokyo Japanese.
      Polite product presenter. Moderate pace. Not theatrical.
    TEXT

    FEMALE_INSTRUCTIONS_EN = <<~TEXT.freeze
      Speak as a gentle woman around 22-25: soft smile, warm, helpful.
      Clearly feminine soft bright voice. Polite modern AI host. Never male or deep.
    TEXT

    MALE_INSTRUCTIONS_EN = <<~TEXT.freeze
      Speak as a calm approachable man in his late 20s. Polite modern presenter.
    TEXT

    def initialize(text:, voice: nil, language: 'ja', gender: nil)
      @text = text
      @language = language.to_s.presence || 'ja'
      @gender = gender.presence || Deal::DEFAULT_TTS_VOICE_GENDER
      @voice = voice.presence || Deal::OPENAI_TTS_VOICE_BY_GENDER[@gender] ||
               Deal::OPENAI_TTS_VOICE_BY_GENDER[Deal::DEFAULT_TTS_VOICE_GENDER]
    end

    def generate_speech
      api_key = ENV['OPENAI_API_KEY']
      raise 'OPENAI_API_KEY is not set' if api_key.blank?

      client = OpenAI::Client.new(access_token: api_key)

      client.audio.speech(
        parameters: {
          model: MODEL,
          input: @text,
          voice: @voice,
          instructions: instructions_for_voice,
          response_format: 'mp3'
        }
      )
    rescue => e
      Rails.logger.error("OpenAI TTS Error (model=#{MODEL} voice=#{@voice} gender=#{@gender}): #{e.class}: #{e.message}")
      raise
    end

    def self.generate_from_deal_summary(deal)
      return nil unless deal.deal_summary.present?

      text = build_speech_text(deal)

      new(
        text: text,
        voice: deal.openai_tts_voice,
        language: deal.language,
        gender: deal.tts_voice_gender
      ).generate_speech
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

    private

    def instructions_for_voice
      japanese = @language.to_s.downcase.start_with?('ja')
      if @gender == 'male'
        japanese ? MALE_INSTRUCTIONS_JA : MALE_INSTRUCTIONS_EN
      else
        japanese ? FEMALE_INSTRUCTIONS_JA : FEMALE_INSTRUCTIONS_EN
      end
    end
  end
end
