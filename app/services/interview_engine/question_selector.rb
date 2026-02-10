# app/services/interview_engine/question_selector.rb
module InterviewEngine
  class QuestionSelector
    def initialize(interview)
      @interview = interview
      @situation = interview.situation
    end

    # Get next unanswered question
    def get_next_question
      next_q = unanswered_questions.first
      
      raise "All questions answered" if next_q.nil?
      raise "No questions in situation" if @situation.questions.empty?

      next_q
    end

    # Get question text and generate TTS audio
    def prepare_question_audio(question, language: 'en')
      audio_record = ensure_question_audio(question, language)

      {
        question_id: question.id,
        question_text: question.question_text,
        question_type: question.question_type,
        audio_url: audio_record&.audio&.attached? ? audio_url(audio_record.audio) : nil,
        order: question.order,
        total_questions: @situation.questions.count,
        options: question.multiple_choice? ? question.parsed_options : nil,
        avatar_url: avatar_url
      }
    end

    # Get question without audio (text only)
    def get_question_text(question)
      {
        question_id: question.id,
        question_text: question.question_text,
        question_type: question.question_type,
        order: question.order,
        total_questions: @situation.questions.count,
        options: question.multiple_choice? ? question.parsed_options : nil,
        avatar_url: avatar_url
      }
    end

    # Check if interview should continue
    def should_continue_interview?
      unanswered_questions.any?
    end

    private

    def unanswered_questions
      @interview.situation.questions.where.not(
        id: @interview.interview_responses.select(:question_id)
      ).order(:order)
    end

    def ensure_question_audio(question, language)
      record = QuestionAudio.find_or_initialize_by(question: question, language: language)
      return record if record.audio.attached?

      tts_client = TTSClient.new
      audio_path = tts_client.speak(question.question_text, language: language)
      return record if audio_path.nil?

      File.open(audio_path, 'rb') do |file|
        record.audio.attach(
          io: file,
          filename: File.basename(audio_path),
          content_type: 'audio/mpeg'
        )
      end

      record.save!
      record
    end

    def audio_url(audio_attachment)
      Rails.application.routes.url_helpers.rails_blob_path(audio_attachment, only_path: true)
    end

    def avatar_url
      ActionController::Base.helpers.asset_path('image.png')
    end
  end
end
