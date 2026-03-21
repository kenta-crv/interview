# app/services/interview_engine/audio_interview_service.rb
#
# 音声面接のEnd-to-Endフローを管理するサービス。
# コントローラーから呼ばれ、音声入力→STT→テキスト取得→評価送信の一連のパイプラインを統合する。
#
module InterviewEngine
  class AudioInterviewService
    class AudioError < StandardError; end

    def initialize(interview)
      @interview = interview
      @language = interview.language || 'en'
    end

    # 質問の音声データを取得（キャッシュ付き）
    # returns: { question_id:, question_text:, audio_url:, ... }
    def prepare_question(question)
      selector = QuestionSelector.new(@interview)
      selector.prepare_question_audio(question, language: @language)
    end

    # 音声/動画ファイルから回答テキストを取得
    # returns: { transcript:, audio_path:, extracted_audio_path: }
    def process_answer_media(audio_file: nil, video_file: nil, text_answer: nil)
      # テキスト回答がある場合はそのまま返す
      if text_answer.present?
        return { transcript: text_answer, audio_path: nil, extracted_audio_path: nil }
      end

      extracted_audio_path = nil
      target_audio_path = nil

      if audio_file
        target_audio_path = audio_file.path
        validate_audio!(target_audio_path)
      elsif video_file
        extracted_audio_path = MediaProcessor.extract_audio_from_video(video_file.path)
        target_audio_path = extracted_audio_path
      else
        raise AudioError, "No answer input provided (audio_file, video_file, or text_answer required)"
      end

      # 音声長のバリデーション
      MediaProcessor.validate_audio_duration!(target_audio_path)

      # STT実行
      stt_client = STTClient.new
      transcript = stt_client.transcribe(target_audio_path, language: @language)

      unless transcript.present?
        raise AudioError, "Failed to transcribe audio"
      end

      {
        transcript: transcript,
        audio_path: audio_file&.path,
        extracted_audio_path: extracted_audio_path
      }
    end

    # 一時ファイルのクリーンアップ
    def cleanup_temp_files(*paths)
      paths.compact.each do |path|
        File.delete(path) if File.exist?(path)
      rescue => e
        Rails.logger.warn("Failed to delete temp file #{path}: #{e.message}")
      end
    end

    # Situation単位で全質問の音声を事前生成（バッチ用）
    def self.pregenerate_question_audio(situation, language: nil)
      language ||= situation.language || 'en'
      tts_client = TTSClient.new

      # N+1回避: 既存のQuestionAudioを事前ロードし、音声生成済みの質問IDを取得
      existing_question_ids = QuestionAudio
        .where(language: language)
        .joins(:audio_attachment)
        .where(question_id: situation.questions.select(:id))
        .pluck(:question_id)
        .to_set

      situation.questions.order(:order).each do |question|
        next if existing_question_ids.include?(question.id)

        record = QuestionAudio.find_or_initialize_by(question: question, language: language)

        audio_path = tts_client.speak(question.question_text, language: language)
        next if audio_path.nil?

        File.open(audio_path, 'rb') do |file|
          record.audio.attach(
            io: file,
            filename: File.basename(audio_path),
            content_type: 'audio/mpeg'
          )
        end
        record.save!

        File.delete(audio_path) if File.exist?(audio_path)

        Rails.logger.info("Pre-generated audio for question ##{question.id} (#{language})")
      rescue => e
        Rails.logger.error("Failed to pre-generate audio for question ##{question.id}: #{e.message}")
      end
    end

    private

    def validate_audio!(audio_path)
      raise AudioError, "Audio file not found" unless File.exist?(audio_path)
      raise AudioError, "Audio file is empty" if File.size(audio_path).zero?

      max_size = Rails.application.config.interview.stt_max_file_size
      if File.size(audio_path) > max_size
        raise AudioError, "Audio file too large (max #{max_size / 1024 / 1024}MB)"
      end
    end
  end
end
