# app/controllers/api/interviews_controller.rb
module Api
  class InterviewsController < ApplicationController
    skip_before_action :verify_authenticity_token
    
    before_action :authenticate_user!, unless: :test_mode?
    
    before_action :set_current_user
    before_action :validate_interview_exists, only: [:next_question, :submit_answer, :complete, :status]
    before_action :set_interview, only: [:next_question, :submit_answer, :complete, :status]

    # POST /api/interviews/start
    # Start a new interview session
    def start
      situation = Situation.find(params[:situation_id])
      language = params[:language].presence || situation.language || 'en'

      session_manager = InterviewEngine::SessionManager.new(@current_user, situation)
      interview = session_manager.start_interview(language: language)

      render json: {
        success: true,
        interview_id: interview.id,
        status: interview.status,
        total_questions: interview.total_questions,
        language: interview.language
      }, status: :created
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end

    # GET /api/interviews/:id/next_question
    # Get the next question with audio
    def next_question
      unless @interview.in_progress?
        return render json: { success: false, error: 'Interview not in progress' }, status: :bad_request
      end

      begin
        selector = InterviewEngine::QuestionSelector.new(@interview)
        
        unless selector.should_continue_interview?
          return render json: {
            success: true,
            message: 'All questions answered',
            interview_complete: true
          }
        end

        question = selector.get_next_question
        language = params[:language].presence || @interview.language || 'en'

        # Generate TTS audio for question
        audio_data = selector.prepare_question_audio(question, language: language)

        render json: {
          success: true,
          question: audio_data
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :bad_request
      end
    end

    # POST /api/interviews/:id/answer
    # Submit voice answer for a question
    def submit_answer
      question_id = params[:question_id]
      audio_file = params[:audio_file]
      video_file = params[:video_file]
      text_answer = params[:text_answer].presence || params[:selected_option].presence
      language = params[:language].presence || @interview.language || 'en'

      # Validate inputs
      unless question_id && (audio_file || video_file || text_answer.present?)
        return render json: {
          success: false,
          error: 'Missing question_id or answer input'
        }, status: :bad_request
      end

      question = Question.find_by(id: question_id, situation_id: @interview.situation_id)
      unless question
        return render json: {
          success: false,
          error: 'Question not found'
        }, status: :not_found
      end

      begin
        # Check if already answered
        existing_response = @interview.interview_responses.find_by(question_id: question_id)
        if existing_response
          return render json: {
            success: false,
            error: 'Question already answered'
          }, status: :bad_request
        end

        transcript = text_answer.presence
        extracted_audio_path = nil

        # Convert audio/video to text if no text provided
        if transcript.blank?
          stt_client = InterviewEngine::STTClient.new

          if audio_file
            transcript = stt_client.transcribe(audio_file.path, language: language)
          elsif video_file
            extracted_audio_path = InterviewEngine::MediaProcessor.extract_audio_from_video(video_file.path)
            transcript = stt_client.transcribe(extracted_audio_path, language: language)
          end
        end

        unless transcript
          return render json: {
            success: false,
            error: 'Failed to transcribe audio'
          }, status: :bad_request
        end

        # Create response record
        response = @interview.interview_responses.create!(
          question: question,
          audio_transcript: transcript,
          evaluation_status: :pending
        )

        if audio_file
          response.answer_audio.attach(audio_file)
        elsif extracted_audio_path
          File.open(extracted_audio_path, 'rb') do |file|
            response.answer_audio.attach(
              io: file,
              filename: File.basename(extracted_audio_path),
              content_type: 'audio/wav'
            )
          end
        end

        if video_file
          response.answer_video.attach(video_file)
        end

        if extracted_audio_path && File.exist?(extracted_audio_path)
          File.delete(extracted_audio_path)
        end

        # Evaluate response asynchronously
        EvaluateInterviewResponseJob.perform_later(response.id)

        render json: {
          success: true,
          message: 'Response submitted for evaluation',
          response_id: response.id
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: {
          success: false,
          error: "Failed to save response: #{e.message}"
        }, status: :unprocessable_entity
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :bad_request
      end
    end

    # POST /api/interviews/:id/complete
    # Complete the interview and generate results
    def complete
      unless @interview.in_progress?
        return render json: {
          success: false,
          error: 'Interview not in progress'
        }, status: :bad_request
      end

      begin
        session_manager = InterviewEngine::SessionManager.new(
          @interview.user,
          @interview.situation
        )
        
        result = session_manager.complete_interview(@interview.id)

        render json: {
          success: true,
          message: 'Interview completed',
          result: {
            interview_id: @interview.id,
            final_status: result.final_status,
            average_score: result.results_data&.dig('average_score'),
            total_questions: result.results_data&.dig('total_questions'),
            answered_questions: result.results_data&.dig('answered_questions')
          }
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end
    end

    # GET /api/interviews/:id/status
    # Get current interview status
    def status
      begin
        session_manager = InterviewEngine::SessionManager.new(
          @current_user,
          @interview.situation
        )
        
        state = session_manager.get_interview_state(@interview.id)

        render json: {
          success: true,
          state: state.merge(language: @interview.language)
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :bad_request
      end
    end

    private

    def set_interview
      @interview = Interview.find(params[:id])
      authorize_interview!
    end

    def validate_interview_exists
      unless Interview.exists?(params[:id])
        render json: {
          success: false,
          error: 'Interview not found'
        }, status: :not_found
        return
      end
    end

    def set_current_user
      # For development testing - use test user if no auth
      @current_user = test_mode? ? (User.find_by(email: 'test@interview.com') || User.first) : current_user
    end

    def test_mode?
      ENV['AI_INTERVIEW_TEST_MODE'] == 'true'
    end

    def authorize_interview!
      return if test_mode?

      unless @interview.user == current_user
        render json: {
          success: false,
          error: 'Unauthorized'
        }, status: :forbidden
      end
    end
  end
end
