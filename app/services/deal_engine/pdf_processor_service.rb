# app/services/deal_engine/pdf_processor_service.rb
require 'pdf-reader'

module DealEngine
  class PdfProcessorService
    def initialize(deal_document, script_generator: nil)
      @deal_document = deal_document
      @deal = deal_document.deal
      @script_generator = script_generator || ScriptGeneratorService.new(@deal)
    end

    def process!
      return unless @deal_document.file.attached?
      return unless @deal_document.content_type&.include?('pdf')

      @pdf_tempfile = download_pdf
      pdf_path = @pdf_tempfile.path
      page_count = get_page_count(pdf_path)

      page_count.times do |page_index|
        process_page(pdf_path, page_index + 1, page_count)
      end
    ensure
      @pdf_tempfile&.close!
      @pdf_tempfile = nil
    end

    private

    def download_pdf
      temp_file = Tempfile.new(['pdf', '.pdf'], binmode: true)
      temp_file.write(@deal_document.file.download)
      temp_file.flush
      temp_file
    end

    def get_page_count(pdf_path)
      PDF::Reader.new(pdf_path).page_count
    end

    def process_page(pdf_path, page_number, total_pages)
      page_text = @script_generator.extract_page_text(pdf_path, page_number)
      generated = @script_generator.generate_page_script(
        page_number: page_number,
        page_text: page_text,
        total_pages: total_pages
      )

      deal_page = @deal.deal_pages.create!(
        deal_document: @deal_document,
        page_number: page_number,
        title: generated['title'] || generated[:title],
        page_text: page_text,
        script: generated['script'] || generated[:script]
      )

      AudioGeneratorService.new(@deal).generate_for_page!(deal_page)
    end
  end
end
