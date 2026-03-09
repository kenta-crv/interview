# app/services/interview_engine/session_manager.rb
module InterviewEngine
  class SessionManager
    class SessionError < StandardError; end
    class TimeoutError < SessionError; end
    class ResumeError < SessionError; end

    def initialize(user, situation)
      @user = user
      @situation = situation
    end

    # Start a new interview session
    def start_interview(language: 'en')
      # 既存のin_progress面接があればそれを返す（中断復帰の簡易パス）
      existing_in_progress = Interview.by_user_and_situation(@user, @situation)
                                      .where(status: :in_progress).first
      if existing_in_progress
        existing_in_progress.touch_activity!
        return existing_in_progress
      end

      # 完了/失敗済み面接がある場合は再受験不可
      existing_done = Interview.by_user_and_situation(@user, @situation).completed_or_failed.first
      raise SessionError, "Interview already completed for this situation" if existing_done

      # abandoned面接があれば復帰を試みる
      existing_abandoned = Interview.by_user_and_situation(@user, @situation)
                                    .where(status: :abandoned).first
      if existing_abandoned && existing_abandoned.resumable?
        return resume_interview(existing_abandoned.id)
      end

      interview = Interview.create!(
        user: @user,
        situation: @situation,
        status: :not_started,
        language: language
      )

      interview.start!
      interview
    rescue ActiveRecord::RecordInvalid => e
      raise SessionError, "Failed to start interview: #{e.message}"
    end

    # トークンで面接を開始/復帰（Devise認証不要）
    def self.start_by_token(access_token)
      interview = Interview.by_token(access_token).first
      raise SessionError, "Invalid interview token" unless interview

      manager = new(interview.user, interview.situation)
      manager.handle_token_start(interview)
    end

    def handle_token_start(interview)
      if interview.in_progress?
        if interview.timed_out?
          interview.abandon!
          raise TimeoutError, "Interview session has timed out"
        end
        interview.touch_activity!
        interview
      elsif interview.not_started?
        interview.start!
        interview
      elsif interview.abandoned?
        if interview.resumable?
          resume_interview(interview.id)
        else
          raise ResumeError, "Interview cannot be resumed (max retries exceeded)"
        end
      elsif interview.completed? || interview.failed?
        raise SessionError, "Interview has already ended (#{interview.status})"
      end
    end

    # 面接を再開
    def resume_interview(interview_id)
      interview = Interview.find(interview_id)

      unless interview.resumable?
        raise ResumeError, "Interview cannot be resumed"
      end

      interview.resume!
      interview
    end

    # セッションアクティビティを更新（タイムアウト延長）
    def touch_session(interview_id)
      interview = Interview.find(interview_id)

      if interview.timed_out?
        interview.abandon!
        raise TimeoutError, "Interview session has timed out"
      end

      interview.touch_activity!
      interview
    end

    # タイムアウトチェック（操作前に呼ぶ）
    def check_timeout!(interview_id)
      interview = Interview.find(interview_id)
      return unless interview.in_progress?

      if interview.timed_out?
        interview.abandon!
        raise TimeoutError, "Interview session has timed out"
      end
    end

    # Get current interview state
    def get_interview_state(interview_id)
      interview = Interview.find(interview_id)

      {
        interview_id: interview.id,
        status: interview.status,
        progress: interview.progress_percentage,
        answered_questions: interview.answered_question_count,
        total_questions: interview.total_questions,
        duration_seconds: interview.started_at ? (Time.current - interview.started_at).to_i : 0,
        remaining_seconds: interview.remaining_seconds,
        resume_count: interview.resume_count,
        resumable: interview.resumable?
      }
    end

    # Mark interview as failed
    def fail_interview(interview_id, reason)
      interview = Interview.find(interview_id)
      interview.fail!

      InterviewResult.create!(
        interview: interview,
        final_status: :failed,
        results_data: {
          failure_reason: reason,
          completed_at: Time.current
        }
      )

      true
    end

    # Complete interview and generate results
    def complete_interview(interview_id)
      interview = Interview.find(interview_id)

      # Ensure all responses are evaluated
      pending_responses = interview.interview_responses.where(evaluation_status: :pending)
      raise SessionError, "Cannot complete: #{pending_responses.count} responses still pending evaluation" if pending_responses.any?

      interview.complete!

      generate_interview_result(interview)
    end

    # タイムアウトした面接を一括abandon（バッチ処理用）
    def self.expire_timed_out_sessions!
      Interview.where(status: :in_progress)
               .where.not(last_activity_at: nil)
               .includes(:situation)
               .find_each do |interview|
        if interview.timed_out?
          interview.abandon!
          Rails.logger.info("Interview ##{interview.id} expired due to timeout")
        end
      end
    end

    private

    def generate_interview_result(interview)
      responses = interview.interview_responses.includes(:question).in_order

      passed_responses = responses.passed_evaluation.count
      total_responses = responses.count
      scores = responses.evaluated.map(&:score).compact

      average_score = scores.empty? ? 0 : (scores.sum.to_f / scores.count).round(2)
      final_status = average_score >= 70 ? :passed : :failed

      summary_data = generate_summary(responses, interview.language)
      conversation_log = responses.map do |r|
        {
          question: r.question.question_text,
          answer: r.audio_transcript,
          score: r.score
        }
      end

      result_data = {
        total_questions: interview.total_questions,
        answered_questions: total_responses,
        skipped_questions: interview.total_questions - total_responses,
        average_score: average_score,
        passed_count: passed_responses,
        summary: summary_data[:summary],
        strengths: summary_data[:strengths],
        weaknesses: summary_data[:weaknesses],
        recommendation: summary_data[:recommendation],
        conversation_log: conversation_log,
        responses_summary: responses.map { |r|
          {
            question: r.question.question_text,
            score: r.score,
            passed: r.passed_evaluation?
          }
        }
      }

      InterviewResult.create!(
        interview: interview,
        final_status: final_status,
        results_data: result_data
      )
    end

    def generate_summary(responses, language)
      llm = LLMClient.new
      summary = llm.summarize_interview(responses, language: language)

      {
        summary: summary[:summary],
        strengths: summary[:strengths] || [],
        weaknesses: summary[:weaknesses] || [],
        recommendation: summary[:recommendation]
      }
    rescue => e
      Rails.logger.error("Summary generation error: #{e.message}")
      {
        summary: 'Summary unavailable',
        strengths: [],
        weaknesses: [],
        recommendation: 'Review required'
      }
    end
  end
end
