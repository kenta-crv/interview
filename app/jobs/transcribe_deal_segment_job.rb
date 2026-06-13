# app/jobs/transcribe_deal_segment_job.rb
class TranscribeDealSegmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(deal_segment_id)
    segment = DealSegment.find(deal_segment_id)

    # べき等性チェック: 既に完了している場合はスキップ
    return if segment.completed?

    segment.update!(transcription_status: :processing)

    unless segment.audio_file.attached?
      segment.update!(transcription_status: :failed)
      Rails.logger.error("No audio file attached for segment #{segment.id}")
      return
    end

    # 音声ファイルを一時ファイルにダウンロード
    audio_path = download_temp_file(segment.audio_file)

    begin
      # 既存のSTTClientを使用して文字起こし
      language = segment.deal_audio.deal.language || 'ja'
      stt_client = InterviewEngine::STTClient.new
      transcript = stt_client.transcribe(audio_path, language: language)

      segment.update!(
        transcript: transcript,
        transcription_status: :completed
      )

      Rails.logger.info("✅ Segment #{segment.id} transcription completed")
    rescue => e
      segment.update!(transcription_status: :failed)
      Rails.logger.error("❌ Segment #{segment.id} transcription failed: #{e.message}")
      raise
    ensure
      File.delete(audio_path) if File.exist?(audio_path)
    end
  end

  private

  def download_temp_file(audio_file)
    temp_dir = Dir.mktmpdir
    temp_path = File.join(temp_dir, "segment_#{audio_file.filename.basename}")
    File.open(temp_path, 'wb') do |file|
      file.write(audio_file.download)
    end
    temp_path
  end
end
