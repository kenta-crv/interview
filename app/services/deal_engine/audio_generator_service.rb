module DealEngine
  class AudioGeneratorService
    def initialize(deal)
      @deal = deal
    end

    def generate_for_page!(deal_page)
      return unless deal_page.script.present?

      audio_data = TtsService.new(
        text: deal_page.script,
        voice: 'alloy',
        language: @deal.language || 'ja'
      ).generate_speech

      attach_audio(deal_page, audio_data, "page_#{deal_page.page_number}_audio.mp3")
    end

    def generate_opening_audios!
      {
        greeting: @deal.greeting_script,
        company_overview: @deal.company_overview_script,
        usage_guide: @deal.usage_guide_script
      }.each do |kind, script|
        next if script.blank?

        audio_data = TtsService.new(
          text: script,
          voice: 'alloy',
          language: @deal.language || 'ja'
        ).generate_speech

        speech = @deal.deal_speeches.find_or_initialize_by(voice: kind.to_s)
        speech.assign_attributes(
          filename: "#{kind}_#{@deal.id}.mp3",
          content_type: 'audio/mpeg',
          file_size: audio_data.bytesize,
          language: @deal.language
        )
        speech.save!
        speech.audio_file.attach(
          io: StringIO.new(audio_data),
          filename: "#{kind}_#{@deal.id}.mp3",
          content_type: 'audio/mpeg'
        )
      end
    end

    def generate_all!
      @deal.deal_pages.order(:page_number).find_each do |page|
        generate_for_page!(page)
      end
      generate_opening_audios!
    end

    private

    def attach_audio(deal_page, audio_data, filename)
      deal_page.page_audio.purge if deal_page.page_audio.attached?
      deal_page.page_audio.attach(
        io: StringIO.new(audio_data),
        filename: filename,
        content_type: 'audio/mpeg'
      )
      deal_page.update!(
        audio_url: Rails.application.routes.url_helpers.rails_blob_path(deal_page.page_audio, only_path: true)
      )
    end
  end
end
