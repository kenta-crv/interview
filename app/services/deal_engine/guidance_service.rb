# app/services/deal_engine/guidance_service.rb
module DealEngine
  class GuidanceService
    def initialize(presentation)
      @presentation = presentation
      @deal = presentation.deal
      @situation = presentation.situation
    end

    def start_presentation
      @presentation.update!(status: :in_progress, current_step: 'introduction')
      
      guidance = generate_introduction_guidance
      @presentation.add_guidance(guidance)
      
      guidance
    end

    def handle_user_choice(choice)
      @presentation.add_user_choice(choice)
      
      next_guidance = determine_next_guidance(choice)
      @presentation.add_guidance(next_guidance)
      
      next_guidance
    end

    private

    def generate_introduction_guidance
      summary = @deal.deal_summary
      language = @deal.language

      if language == 'ja'
        <<~TEXT
          こんにちは。#{@deal.title}についてご案内いたします。
          
          まず、この商談の概要は以下の通りです：
          #{summary.summary}
          
          重要なポイント：
          #{summary.key_points}
          
          どの点について詳しく知りたいですか？
          1. 全体の詳細について
          2. アクションアイテムについて
          3. 次のステップについて
          4. 特定の質問がある
        TEXT
      else
        <<~TEXT
          Hello. I will guide you through #{@deal.title}.
          
          First, here's an overview of this deal:
          #{summary.summary}
          
          Key points:
          #{summary.key_points}
          
          What would you like to know more about?
          1. Overall details
          2. Action items
          3. Next steps
          4. I have a specific question
        TEXT
      end
    end

    def determine_next_guidance(choice)
      summary = @deal.deal_summary
      language = @deal.language

      case choice
      when '1', 'overall', '全体の詳細'
        generate_detailed_guidance(summary, language)
      when '2', 'action_items', 'アクションアイテム'
        generate_action_items_guidance(summary, language)
      when '3', 'next_steps', '次のステップ'
        generate_next_steps_guidance(summary, language)
      when '4', 'question', '質問'
        generate_question_prompt(language)
      else
        generate_default_guidance(language)
      end
    end

    def generate_detailed_guidance(summary, language)
      if language == 'ja'
        <<~TEXT
          詳細情報をご案内します。
          
          #{summary.summary}
          
          重要なポイント：
          #{summary.key_points}
          
          参加者情報：
          #{summary.participants || '情報なし'}
          
          他に知りたいことはありますか？
          1. アクションアイテムについて
          2. 次のステップについて
          3. 質問をする
          4. 終了する
        TEXT
      else
        <<~TEXT
          Here are the detailed information.
          
          #{summary.summary}
          
          Key points:
          #{summary.key_points}
          
          Participant information:
          #{summary.participants || 'Not available'}
          
          What else would you like to know?
          1. About action items
          2. About next steps
          3. Ask a question
          4. Finish
        TEXT
      end
    end

    def generate_action_items_guidance(summary, language)
      if language == 'ja'
        <<~TEXT
          アクションアイテムについてご案内します。
          
          #{summary.action_items || 'アクションアイテムはありません'}
          
          他に知りたいことはありますか？
          1. 全体の詳細について
          2. 次のステップについて
          3. 質問をする
          4. 終了する
        TEXT
      else
        <<~TEXT
          Here are the action items.
          
          #{summary.action_items || 'No action items'}
          
          What else would you like to know?
          1. Overall details
          2. Next steps
          3. Ask a question
          4. Finish
        TEXT
      end
    end

    def generate_next_steps_guidance(summary, language)
      if language == 'ja'
        <<~TEXT
          次のステップについてご案内します。
          
          #{summary.next_steps || '次のステップはありません'}
          
          他に知りたいことはありますか？
          1. 全体の詳細について
          2. アクションアイテムについて
          3. 質問をする
          4. 終了する
        TEXT
      else
        <<~TEXT
          Here are the next steps.
          
          #{summary.next_steps || 'No next steps'}
          
          What else would you like to know?
          1. Overall details
          2. Action items
          3. Ask a question
          4. Finish
        TEXT
      end
    end

    def generate_question_prompt(language)
      if language == 'ja'
        <<~TEXT
          ご質問をお聞かせください。
          
          質問を入力すると、資料に基づいて回答いたします。
          
          他の選択肢：
          1. 全体の詳細について
          2. アクションアイテムについて
          3. 次のステップについて
          4. 終了する
        TEXT
      else
        <<~TEXT
          Please ask your question.
          
          I will answer based on the documents.
          
          Other options:
          1. Overall details
          2. Action items
          3. Next steps
          4. Finish
        TEXT
      end
    end

    def generate_default_guidance(language)
      if language == 'ja'
        <<~TEXT
          選択肢を再度表示します。
          
          1. 全体の詳細について
          2. アクションアイテムについて
          3. 次のステップについて
          4. 質問がある
          5. 終了する
        TEXT
      else
        <<~TEXT
          Here are the options again.
          
          1. Overall details
          2. Action items
          3. Next steps
          4. I have a question
          5. Finish
        TEXT
      end
    end
  end
end
