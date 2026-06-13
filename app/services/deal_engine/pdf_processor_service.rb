# app/services/deal_engine/pdf_processor_service.rb
require 'pdf-reader'

module DealEngine
  class PdfProcessorService
    def initialize(deal_document)
      @deal_document = deal_document
      @deal = deal_document.deal
    end

    def process!
      return unless @deal_document.file.attached?
      return unless @deal_document.content_type&.include?('pdf')

      pdf_path = download_pdf
      page_count = get_page_count(pdf_path)

      page_count.times do |page_index|
        process_page(page_index + 1)
      end

      File.delete(pdf_path) if File.exist?(pdf_path)
    end

    private

    def download_pdf
      temp_file = Tempfile.new(['pdf', '.pdf'], binmode: true)
      temp_file.write(@deal_document.file.download)
      temp_file.close
      temp_file.path
    end

    def get_page_count(pdf_path)
      reader = PDF::Reader.new(pdf_path)
      reader.page_count
    end

    def process_page(page_number)
      # DealPageを作成
      deal_page = @deal.deal_pages.create!(
        deal_document: @deal_document,
        page_number: page_number
      )

      # 台本を生成
      script = generate_page_script(deal_page)
      deal_page.update!(script: script)

      # 音声を生成
      audio_url = generate_page_audio(deal_page)
      deal_page.update!(audio_url: audio_url)
    end

    def generate_page_script(deal_page)
      language = @deal.language || 'ja'

      if language == 'ja'
        "それでは、#{deal_page.page_number}ページ目についてご説明いたします。このスライドには、商談における重要なポイントが含まれています。まず、全体の概要から始めましょう。この資料は、私たちの提案内容を視覚的に分かりやすくまとめたものです。各セクションについて順を追って説明させていただきます。何かご質問があれば、いつでもお尋ねください。"
      else
        "Now, let me explain page #{deal_page.page_number}. This slide contains important points about our business discussion. Let's start with an overview. This material visually summarizes our proposal. I will explain each section in order. Please feel free to ask any questions."
      end
    end

    def generate_page_audio(deal_page)
      return nil unless deal_page.script.present?

      # 修正点：Railsの推論（Did you mean?）に合わせて大文字表記から TtsService（または環境に応じて ::TTSService）へ修正
      # もしトップレベル（/app/services/tts_service.rb等）に配置されている場合は、明示的に「::TtsService」か「::TTSService」と記述して依存関係の衝突を防ぎます。
      tts_class = defined?(::DealEngine::TtsService) ? ::DealEngine::TtsService : ::TtsService
      
      tts_service = tts_class.new(
        text: deal_page.script,
        voice: 'alloy',
        language: @deal.language || 'ja'
      )

      audio_data = tts_service.generate_speech

      # 音声ファイルを保存
      audio_file = Tempfile.new(['audio', '.mp3'], binmode: true)
      audio_file.write(audio_data)
      audio_file.close

      # ActiveStorageに保存
      deal_page.page_audio.attach(
        io: File.open(audio_file.path, 'rb'),
        filename: "page_#{deal_page.page_number}_audio.mp3",
        content_type: 'audio/mpeg'
      )

      File.delete(audio_file.path) if File.exist?(audio_file.path)

      Rails.application.routes.url_helpers.rails_blob_path(deal_page.page_audio, only_path: true)
    rescue => e
      Rails.logger.error("Audio generation failed for page #{deal_page.page_number}: #{e.message}")
      nil
    end
  end
end