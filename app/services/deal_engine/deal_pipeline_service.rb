module DealEngine
  class DealPipelineService
    def initialize(deal)
      @deal = deal
    end

    def process!
      @deal.start_processing!

      generate_summary!
      process_pdf_documents!
      script_generator.generate_opening_scripts!
      script_generator.generate_menu_items!
      AudioGeneratorService.new(@deal).generate_all!

      @deal.update!(playback_ready: false)
      @deal.complete!
      Rails.logger.info("DealPipeline completed for deal #{@deal.id}")
    rescue => e
      @deal.fail!
      Rails.logger.error("DealPipeline failed for deal #{@deal.id}: #{e.message}")
      raise
    end

    private

    def generate_summary!
      documents = @deal.send(:collect_documents)
      raise 'No documents attached' if documents.empty?

      result = @deal.send(:generate_claude_summary_from_documents, documents)
      @deal.deal_transcript&.destroy
      @deal.deal_summary&.destroy
      @deal.send(:create_transcript_and_summary, result[:transcript], result[:summary])
    end

    def process_pdf_documents!
      @deal.deal_pages.destroy_all

      @deal.deal_documents.each do |document|
        next unless document.file.attached?
        next unless document.content_type&.include?('pdf')

        PdfProcessorService.new(document, script_generator: script_generator).process!
      end
    end

    def script_generator
      @script_generator ||= ScriptGeneratorService.new(@deal)
    end
  end
end
