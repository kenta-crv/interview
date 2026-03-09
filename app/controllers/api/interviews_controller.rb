# app/controllers/api/interviews_controller.rb
module Api
  class InterviewsController < ApplicationController
    skip_before_action :verify_authenticity_token
    # TODO: Day15セキュリティ強化フェーズでRack::Attackによるレート制限を追加する

    before_action :authenticate_by_token_or_user!, except: [:start_by_token]
    before_action :set_interview, only: [:next_question, :submit_answer, :complete, :status, :resume]
    before_action :check_session_timeout!, only: [:next_question, :submit_answer]

    # POST /api/interviews/start
    def start
      situation = Situation.find(params[:situation_id])
      language = params[:language].presence || situation.language || 'en'

      session_manager = InterviewEngine::SessionManager.new(@current_user, situation)
      interview = session_manager.start_interview(language: language)

      render json: {
        success: true,
        interview_id: interview.id,
        access_token: interview.access_token,
        status: interview.status,
        total_questions: interview.total_questions,
        language: interview.language,
        session_timeout_minutes: situation.session_timeout_minutes,
        remaining_seconds: interview.remaining_seconds
      }, status: :created
    rescue InterviewEngine::SessionManager::SessionError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # POST /api/interviews/start_by_token
    # URL即時開始（Devise認証不要、トークンのみで面接開始/復帰）
    def start_by_token
      access_token = params[:access_token]
      unless access_token.present?
        return render json: { success: false, error: 'access_token is required' }, status: :bad_request
      end

      interview = InterviewEngine::SessionManager.start_by_token(access_token)

      render json: {
        success: true,
        interview_id: interview.id,
        status: interview.status,
        total_questions: interview.total_questions,
        language: interview.language,
        progress: interview.progress_percentage,
        answered_questions: interview.answered_question_count,
        session_timeout_minutes: interview.situation.session_timeout_minutes,
        remaining_seconds: interview.remaining_seconds,
        resume_count: interview.resume_count
      }
    rescue InterviewEngine::SessionManager::TimeoutError => e
      render json: { success: false, error: e.message, reason: 'timeout' }, status: :gone
    rescue InterviewEngine::SessionManager::ResumeError => e
      render json: { success: false, error: e.message, reason: 'resume_limit' }, status: :forbidden
    rescue InterviewEngine::SessionManager::SessionError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # POST /api/interviews/:id/resume
    # 中断した面接を再開
    def resume
      session_manager = InterviewEngine::SessionManager.new(@interview.user, @interview.situation)
      interview = session_manager.resume_interview(@interview.id)

      render json: {
        success: true,
        interview_id: interview.id,
        status: interview.status,
        progress: interview.progress_percentage,
        answered_questions: interview.answered_question_count,
        total_questions: interview.total_questions,
        remaining_seconds: interview.remaining_seconds,
        resume_count: interview.resume_count
      }
    rescue InterviewEngine::SessionManager::ResumeError => e
      render json: { success: false, error: e.message }, status: :forbidden
    end

    # GET /api/interviews/:id/next_question
    def next_question
      unless @interview.in_progress?
        return render json: { success: false, error: 'Interview not in progress' }, status: :bad_request
      end

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
      audio_data = selector.prepare_question_audio(question, language: language)

      @interview.touch_activity!

      render json: {
        success: true,
        question: audio_data,
        remaining_seconds: @interview.remaining_seconds
      }
    rescue => e
      render json: { success: false, error: e.message }, status: :bad_request
    end

    # POST /api/interviews/:id/submit_answer
    def submit_answer
      question_id = params[:question_id]
      audio_file = params[:audio_file]
      video_file = params[:video_file]
      text_answer = params[:text_answer].presence || params[:selected_option].presence
      language = params[:language].presence || @interview.language || 'en'

      unless question_id && (audio_file || video_file || text_answer.present?)
        return render json: {
          success: false,
          error: 'Missing question_id or answer input'
        }, status: :bad_request
      end

      question = Question.find_by(id: question_id, situation_id: @interview.situation_id)
      unless question
        return render json: { success: false, error: 'Question not found' }, status: :not_found
      end

      existing_response = @interview.interview_responses.find_by(question_id: question_id)
      if existing_response
        return render json: { success: false, error: 'Question already answered' }, status: :bad_request
      end

      transcript = text_answer.presence
      extracted_audio_path = nil

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
        return render json: { success: false, error: 'Failed to transcribe audio' }, status: :bad_request
      end

      response = @interview.interview_responses.create!(
        question: question,
        audio_transcript: transcript,
        evaluation_status: :pending
      )

      attach_media(response, audio_file, video_file, extracted_audio_path)

      # NOTE: ActiveStorageがcloudサービス(S3等)の場合、attachは非同期になるため
      # ファイル削除タイミングに注意。現状localサービス前提で同期処理。
      if extracted_audio_path && File.exist?(extracted_audio_path)
        File.delete(extracted_audio_path)
      end

      EvaluateInterviewResponseJob.perform_later(response.id)
      @interview.touch_activity!

      render json: {
        success: true,
        message: 'Response submitted for evaluation',
        response_id: response.id,
        remaining_seconds: @interview.remaining_seconds
      }, status: :created
    rescue ActiveRecord::RecordNotUnique
      render json: { success: false, error: 'Question already answered' }, status: :conflict
    rescue ActiveRecord::RecordInvalid => e
      render json: { success: false, error: "Failed to save response: #{e.message}" }, status: :unprocessable_entity
    rescue => e
      render json: { success: false, error: e.message }, status: :bad_request
    end

    # POST /api/interviews/:id/complete
    def complete
      unless @interview.in_progress?
        return render json: { success: false, error: 'Interview not in progress' }, status: :bad_request
      end

      session_manager = InterviewEngine::SessionManager.new(@interview.user, @interview.situation)
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
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # GET /api/interviews/:id/status
    def status
      session_manager = InterviewEngine::SessionManager.new(@interview.user, @interview.situation)
      state = session_manager.get_interview_state(@interview.id)

      render json: {
        success: true,
        state: state.merge(language: @interview.language)
      }
    rescue => e
      render json: { success: false, error: e.message }, status: :bad_request
    end

    private

    # トークン or Devise認証の統合
    def authenticate_by_token_or_user!
      # ヘッダーまたはパラメータからトークン取得
      token = request.headers['X-Interview-Token'] || params[:access_token]

      if token.present?
        interview = Interview.by_token(token).first
        if interview
          @current_user = interview.user
          return
        end
      end

      # テストモード
      if test_mode?
        @current_user = User.find_by(email: 'test@interview.com') || User.first
        return
      end

      # Devise認証にフォールバック
      authenticate_user!
      @current_user = current_user
    end

    def set_interview
      @interview = Interview.find_by(id: params[:id])
      unless @interview
        render json: { success: false, error: 'Interview not found' }, status: :not_found
        return
      end
      authorize_interview!
    end

    # 操作前のタイムアウトチェック
    def check_session_timeout!
      return unless @interview&.in_progress?

      if @interview.timed_out?
        @interview.abandon!
        render json: {
          success: false,
          error: 'Interview session has timed out',
          reason: 'timeout',
          resumable: @interview.resumable?
        }, status: :gone
      end
    end

    def test_mode?
      return false if Rails.env.production?
      ENV['AI_INTERVIEW_TEST_MODE'] == 'true'
    end

    def authorize_interview!
      return if test_mode?

      token = request.headers['X-Interview-Token'] || params[:access_token]
      if token.present? && @interview.access_token == token
        return
      end

      unless @current_user && @interview.user_id == @current_user.id
        render json: { success: false, error: 'Unauthorized' }, status: :forbidden
      end
    end

    def attach_media(response, audio_file, video_file, extracted_audio_path)
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

      response.answer_video.attach(video_file) if video_file
    end
  end
end
