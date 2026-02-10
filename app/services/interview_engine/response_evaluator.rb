# app/services/interview_engine/response_evaluator.rb
module InterviewEngine
  class ResponseEvaluator
    PASS_THRESHOLD = 70 # Minimum score to pass

    def initialize(interview_response, language: 'en')
      @response = interview_response
      @language = language
      @interview = interview_response.interview
      @question = interview_response.question
    end

    # Evaluate a single response from user
    def evaluate
      return if @response.audio_transcript.blank?

      @response.update!(evaluation_status: :evaluating)

      evaluation = if @question.multiple_choice?
                     evaluate_multiple_choice
                   else
                     llm = LLMClient.new
                     llm.evaluate_response(
                       @question.question_text,
                       @response.audio_transcript,
                       language: @language
                     )
                   end

      # Store evaluation results
      update_response_with_evaluation(evaluation)

      # Check if interview should continue
      check_interview_continuation

      @response
    rescue => e
      Rails.logger.error("Response Evaluation Error: #{e.message}")
      @response.update!(evaluation_status: :failed)
      raise
    end

    private

    def update_response_with_evaluation(evaluation)
      # Calculate final score based on criteria weights
      final_score = calculate_weighted_score(evaluation)

      passed = final_score >= PASS_THRESHOLD

      @response.update!(
        relevance_score: evaluation[:relevance_score],
        correctness_score: evaluation[:correctness_score],
        clarity_score: evaluation[:clarity_score],
        final_score: final_score,
        passed: passed,
        ai_reasoning: evaluation[:reasoning],
        evaluation_status: :completed
      )
    end

    def calculate_weighted_score(evaluation)
      # Weighted average: Relevance (40%), Correctness (40%), Clarity (20%)
      weights = {
        relevance: 0.4,
        correctness: 0.4,
        clarity: 0.2
      }

      score = (
        (evaluation[:relevance_score].to_i * weights[:relevance]) +
        (evaluation[:correctness_score].to_i * weights[:correctness]) +
        (evaluation[:clarity_score].to_i * weights[:clarity])
      ).round(2)

      [score, 100].min # Cap at 100
    end

    def check_interview_continuation
      # If response failed (score < threshold), fail the entire interview
      if @response.final_score < PASS_THRESHOLD
        SessionManager.new(@interview.user, @interview.situation)
          .fail_interview(@interview.id, "Failed at question: #{@question.question_text}")
      end
    end

    def evaluate_multiple_choice
      options = @question.parsed_options
      choices = options['choices'] || options[:choices] || []
      correct = options['correct'] || options[:correct]

      selected = @response.audio_transcript.to_s.strip.downcase
      correct_choice = resolve_correct_choice(correct, choices)

      passed = !correct_choice.nil? && selected == correct_choice.downcase
      score = passed ? 100 : 0

      {
        relevance_score: score,
        correctness_score: score,
        clarity_score: score,
        final_score: score,
        passed: passed,
        reasoning: passed ? 'Correct option selected' : 'Incorrect option selected'
      }
    end

    def resolve_correct_choice(correct, choices)
      return nil if correct.nil?

      if correct.is_a?(Integer)
        choices[correct]
      else
        correct.to_s
      end
    end
  end
end
