# app/services/interview_engine/prompt_template.rb
module InterviewEngine
  class PromptTemplate
    SUPPORTED_LANGUAGES = %w[en ja].freeze

    class << self
      # 回答評価用プロンプト
      def evaluation(question_text:, user_answer:, language: 'en', question_type: 'open')
        lang = normalize_language(language)

        system_message = build_system_message(:evaluation, lang)
        user_message = if question_type == 'open'
                         build_open_evaluation(question_text, user_answer, lang)
                       else
                         build_choice_evaluation(question_text, user_answer, lang)
                       end

        { system: system_message, user: user_message }
      end

      # 面接サマリー用プロンプト
      def summary(responses_data:, language: 'en')
        lang = normalize_language(language)

        system_message = build_system_message(:summary, lang)
        user_message = build_summary_message(responses_data, lang)

        { system: system_message, user: user_message }
      end

      # 期待するJSONスキーマの定義
      def expected_schema(type)
        case type
        when :evaluation
          {
            required_keys: %w[relevance_score correctness_score clarity_score final_score passed reasoning],
            score_keys: %w[relevance_score correctness_score clarity_score final_score],
            boolean_keys: %w[passed],
            string_keys: %w[reasoning],
            score_range: 0..100
          }
        when :summary
          {
            required_keys: %w[summary strengths weaknesses recommendation],
            string_keys: %w[summary recommendation],
            array_keys: %w[strengths weaknesses]
          }
        else
          raise ArgumentError, "Unknown schema type: #{type}"
        end
      end

      private

      def normalize_language(language)
        SUPPORTED_LANGUAGES.include?(language.to_s) ? language.to_s : 'en'
      end

      def build_system_message(type, language)
        case type
        when :evaluation
          if language == 'ja'
            <<~MSG.strip
              あなたは厳格な面接評価者です。候補者の回答を客観的に評価してください。
              絶対にJSON形式のみで回答してください。会話や説明は一切禁止です。
              質問への追加質問も禁止です。指定されたJSONスキーマに厳密に従ってください。
            MSG
          else
            <<~MSG.strip
              You are a strict interview evaluator. Evaluate the candidate's response objectively.
              You MUST respond with valid JSON only. No conversation, no explanations outside JSON.
              Do NOT ask follow-up questions. Follow the specified JSON schema exactly.
            MSG
          end
        when :summary
          if language == 'ja'
            <<~MSG.strip
              あなたは厳格な面接サマリー生成者です。面接結果を構造化して要約してください。
              絶対にJSON形式のみで回答してください。会話や説明は一切禁止です。
              指定されたJSONスキーマに厳密に従ってください。
            MSG
          else
            <<~MSG.strip
              You are a strict interview summarizer. Produce structured summaries of interview results.
              You MUST respond with valid JSON only. No conversation, no explanations outside JSON.
              Follow the specified JSON schema exactly.
            MSG
          end
        end
      end

      def build_open_evaluation(question_text, user_answer, language)
        if language == 'ja'
          <<~PROMPT.strip
            以下の面接質問と候補者の回答を評価してください。

            【面接質問】
            "#{sanitize(question_text)}"

            【候補者の回答】
            "#{sanitize(user_answer)}"

            【評価基準】
            1. relevance_score (0-100): 回答が質問に適切に対応しているか
            2. correctness_score (0-100): 情報が正確か
            3. clarity_score (0-100): 回答が明確で構造化されているか

            【出力ルール】
            - 会話禁止
            - 追加質問禁止
            - JSON出力のみ
            - スコアは必ず0-100の整数
            - 完全に無関係な回答は全スコア0

            以下のJSON形式のみで出力してください:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<簡潔な評価理由>"}
          PROMPT
        else
          <<~PROMPT.strip
            Evaluate the following interview question and candidate's answer.

            INTERVIEW QUESTION:
            "#{sanitize(question_text)}"

            CANDIDATE'S ANSWER:
            "#{sanitize(user_answer)}"

            EVALUATION CRITERIA:
            1. relevance_score (0-100): Does the answer address the question?
            2. correctness_score (0-100): Is the information accurate?
            3. clarity_score (0-100): Is the answer clear and well-structured?

            OUTPUT RULES:
            - No conversation
            - No follow-up questions
            - JSON output ONLY
            - All scores must be integers 0-100
            - If answer is completely irrelevant, set all scores to 0

            Return ONLY this JSON format:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<brief evaluation>"}
          PROMPT
        end
      end

      def build_choice_evaluation(question_text, user_answer, language)
        if language == 'ja'
          <<~PROMPT.strip
            以下の選択式面接質問に対する候補者の選択を評価してください。

            【質問】
            "#{sanitize(question_text)}"

            【候補者の選択】
            "#{sanitize(user_answer)}"

            以下のJSON形式のみで出力してください:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<簡潔な評価理由>"}
          PROMPT
        else
          <<~PROMPT.strip
            Evaluate the candidate's selection for the following multiple-choice interview question.

            QUESTION:
            "#{sanitize(question_text)}"

            CANDIDATE'S SELECTION:
            "#{sanitize(user_answer)}"

            Return ONLY this JSON format:
            {"relevance_score": <0-100>, "correctness_score": <0-100>, "clarity_score": <0-100>, "final_score": <0-100>, "passed": <true|false>, "reasoning": "<brief evaluation>"}
          PROMPT
        end
      end

      def build_summary_message(responses_data, language)
        raise ArgumentError, "responses_data must not be empty" if responses_data.blank?

        serialized = responses_data.map do |r|
          { question: r[:question], answer: r[:answer], score: r[:score] }
        end

        if language == 'ja'
          <<~PROMPT.strip
            以下の面接回答データを要約してください。

            【回答データ】
            #{serialized.to_json}

            【出力ルール】
            - 会話禁止
            - JSON出力のみ
            - 要約は5文以内
            - strengthsとweaknessesは各3項目以内

            以下のJSON形式のみで出力してください:
            {"summary": "<要約>", "strengths": ["<強み1>", "<強み2>"], "weaknesses": ["<弱み1>", "<弱み2>"], "recommendation": "<採用推奨/不推奨/再検討>"}
          PROMPT
        else
          <<~PROMPT.strip
            Summarize the following interview response data.

            RESPONSES:
            #{serialized.to_json}

            OUTPUT RULES:
            - No conversation
            - JSON output ONLY
            - Summary under 5 sentences
            - Max 3 items each for strengths and weaknesses

            Return ONLY this JSON format:
            {"summary": "<summary>", "strengths": ["<strength1>", "<strength2>"], "weaknesses": ["<weakness1>", "<weakness2>"], "recommendation": "<hire/no hire/review>"}
          PROMPT
        end
      end

      # ユーザー入力のサニタイズ（プロンプトインジェクション対策）
      # delimiter方式でユーザー入力を囲み、プロンプトとの境界を明確にする
      def sanitize(text)
        return '' if text.nil?

        sanitized = text.to_s
                        .gsub(/```/, '\'\'\'')
                        .strip
                        .truncate(2000)

        "---BEGIN USER INPUT---\n#{sanitized}\n---END USER INPUT---"
      end
    end
  end
end
