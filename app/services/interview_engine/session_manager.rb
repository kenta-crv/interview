# app/services/interview_engine/session_manager.rb
module InterviewEngine
  class SessionManager
    def initialize(user, situation)
      @user = user
      @situation = situation
    end

    # Start a new interview session
    def start_interview(language: 'en')
      # Check if interview already exists and completed
      existing = Interview.by_user_and_situation(@user, @situation).completed_or_failed.first
      raise "Interview already completed for this situation" if existing

      # Create new interview
      interview = Interview.create!(
        user: @user,
        situation: @situation,
        status: :not_started,
        language: language
      )

      interview.start!
      interview
    rescue ActiveRecord::RecordInvalid => e
      raise "Failed to start interview: #{e.message}"
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
        duration_seconds: interview.started_at ? (Time.current - interview.started_at).to_i : 0
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
      raise "Cannot complete: #{pending_responses.count} responses still pending evaluation" if pending_responses.any?

      interview.complete!
      
      # Generate and store results
      result = generate_interview_result(interview)
      result
    end

    private

    def generate_interview_result(interview)
      responses = interview.interview_responses.in_order
      
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
        summary: summary[:summary] || summary['summary'],
        strengths: summary[:strengths] || summary['strengths'] || [],
        weaknesses: summary[:weaknesses] || summary['weaknesses'] || [],
        recommendation: summary[:recommendation] || summary['recommendation']
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
