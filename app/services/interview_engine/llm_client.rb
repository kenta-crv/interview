# app/services/interview_engine/llm_client.rb
module InterviewEngine
  class LLMClient
    require 'net/http'
    require 'json'

    OPENAI_API_KEY = ENV['OPENAI_API_KEY']
    OPENAI_URL = 'https://api.openai.com/v1/chat/completions'
    
    CLAUDE_API_KEY = ENV['CLAUDE_API_KEY']
    CLAUDE_URL = 'https://api.anthropic.com/v1/messages'

    def initialize(model: 'openai')
      @model = model
    end

    # Evaluate interview response with strict JSON output
    def evaluate_response(question_text, user_answer, language: 'en')
      prompt = build_evaluation_prompt(question_text, user_answer, language)
      
      case @model
      when 'openai'
        evaluate_with_openai(prompt)
      when 'claude'
        evaluate_with_claude(prompt)
      else
        raise ArgumentError, "Unknown model: #{@model}"
      end
    rescue => e
      Rails.logger.error("LLM Evaluation Error: #{e.message}")
      default_error_response
    end

    # Generate interview summary and feedback
    def summarize_interview(responses, language: 'en')
      prompt = build_summary_prompt(responses, language)

      case @model
      when 'openai'
        evaluate_with_openai(prompt)
      when 'claude'
        evaluate_with_claude(prompt)
      else
        raise ArgumentError, "Unknown model: #{@model}"
      end
    rescue => e
      Rails.logger.error("LLM Summary Error: #{e.message}")
      default_summary_response
    end

    private

    def build_evaluation_prompt(question_text, user_answer, language)
      language_instruction = language == 'ja' ? '日本語で出力してください。' : 'Respond in English.'
      
      <<~PROMPT
        You are a strict interview evaluator. Evaluate the candidate's response ONLY based on the provided criteria.
        
        #{language_instruction}
        
        INTERVIEW QUESTION:
        "#{question_text}"
        
        CANDIDATE'S ANSWER:
        "#{user_answer}"
        
        EVALUATION CRITERIA:
        1. Relevance (0-100): Does the answer address the question?
        2. Correctness (0-100): Is the information accurate?
        3. Clarity (0-100): Is the answer clear and well-structured?
        
        IMPORTANT RULES:
        - Do NOT engage in conversation
        - Do NOT ask follow-up questions
        - Provide ONLY JSON output
        - No explanations outside JSON
        - All scores must be 0-100
        - If answer is completely irrelevant, set all scores to 0
        
        Return ONLY valid JSON in this format:
        {
          "relevance_score": <0-100>,
          "correctness_score": <0-100>,
          "clarity_score": <0-100>,
          "final_score": <0-100>,
          "passed": <true|false>,
          "reasoning": "<brief explanation>"
        }
      PROMPT
    end

    def build_summary_prompt(responses, language)
      language_instruction = language == 'ja' ? '日本語で出力してください。' : 'Respond in English.'
      serialized = responses.map do |r|
        {
          question: r.question.question_text,
          answer: r.audio_transcript,
          score: r.score
        }
      end

      <<~PROMPT
        You are a strict interview summarizer. Produce a concise summary and structured feedback.

        #{language_instruction}

        RESPONSES (JSON):
        #{serialized.to_json}

        IMPORTANT RULES:
        - Do NOT engage in conversation
        - Provide ONLY JSON output
        - No explanations outside JSON
        - Keep summary under 5 sentences

        Return ONLY valid JSON in this format:
        {
          "summary": "<short summary>",
          "strengths": ["<strength 1>", "<strength 2>"],
          "weaknesses": ["<weakness 1>", "<weakness 2>"],
          "recommendation": "<hire/no hire or next step>"
        }
      PROMPT
    end

    def evaluate_with_openai(prompt)
      uri = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{OPENAI_API_KEY}"
      request['Content-Type'] = 'application/json'

      body = {
        model: 'gpt-4',
        messages: [
          { role: 'system', content: 'You are an interview evaluator. Return ONLY valid JSON.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 500
      }

      request.body = body.to_json
      response = http.request(request)
      parse_llm_response(response.body)
    end

    def evaluate_with_claude(prompt)
      uri = URI(CLAUDE_URL)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request['x-api-key'] = CLAUDE_API_KEY
      request['anthropic-version'] = '2023-06-01'
      request['Content-Type'] = 'application/json'

      body = {
        model: 'claude-3-sonnet-20240229',
        max_tokens: 500,
        messages: [
          { role: 'user', content: prompt }
        ]
      }

      request.body = body.to_json
      response = http.request(request)
      parse_llm_response(response.body)
    end

    def parse_llm_response(response_body)
      parsed = JSON.parse(response_body)
      
      # Extract text content
      content = if parsed['choices']&.first&.dig('message', 'content')
                  parsed['choices'].first['message']['content']
                elsif parsed['content']&.first&.dig('text')
                  parsed['content'].first['text']
                else
                  raise "Invalid LLM response structure"
                end

      # Extract JSON from response
      json_match = content.match(/\{[\s\S]*\}/)
      raise "No JSON found in LLM response" unless json_match

      JSON.parse(json_match[0]).with_indifferent_access
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse LLM response: #{e.message}")
      default_error_response
    end

    def default_error_response
      {
        relevance_score: 0,
        correctness_score: 0,
        clarity_score: 0,
        final_score: 0,
        passed: false,
        reasoning: 'Evaluation failed - please retry'
      }
    end

    def default_summary_response
      {
        summary: 'Summary unavailable',
        strengths: [],
        weaknesses: [],
        recommendation: 'Review required'
      }
    end
  end
end
