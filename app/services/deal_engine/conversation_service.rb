module DealEngine
  class ConversationService
    MODEL = 'gpt-5.4-nano'
    HISTORY_LIMIT = 8

    def initialize(deal, user_progress: nil)
      @deal = deal
      @user_progress = user_progress
      @language = deal.language || 'ja'
    end

    def respond(topic: nil, message: nil, page_number: nil, history: [])
      if page_number.present?
        return page_response(page_number.to_i)
      end

      if topic.present?
        menu_item = find_menu_item(topic)
        return page_response(menu_item['page_number']) if menu_item
      end

      free_text = message.presence || topic
      generate_ai_response(free_text, history: history)
    end

    private

    def page_response(page_number)
      page = @deal.deal_pages.find_by(page_number: page_number)
      unless page
        return generate_ai_response(@language == 'ja' ? "#{page_number}ページ目について教えてください" : "Tell me about page #{page_number}")
      end

      {
        type: 'page',
        text: page.script.presence || "#{page.title || page_number}ページ目についてご説明します。",
        page_number: page.page_number,
        page_title: page.title,
        audio_url: audio_url_for(page.page_audio),
        follow_up: nil
      }
    end

    def find_menu_item(topic)
      @deal.presentation_menu_items.find { |item| item['key'] == topic.to_s } ||
        @deal.menu_items_for_conversation.find { |item| item['key'] == topic.to_s }
    end

    def generate_ai_response(message, history: [])
      api_key = ENV['OPENAI_API_KEY']
      return fallback_payload(message) if api_key.blank?

      uri = URI.parse('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{api_key}"
      request.body = {
        model: MODEL,
        messages: build_messages(message, history),
        max_completion_tokens: 800,
        temperature: 0.7
      }.to_json

      response = http.request(request)
      body = JSON.parse(response.body)
      text = body.dig('choices', 0, 'message', 'content').presence || fallback_response(message)

      {
        type: 'ai',
        text: text,
        audio_url: synthesize_reply_audio(text),
        follow_up: follow_up_prompt
      }
    rescue => e
      Rails.logger.error("ConversationService error: #{e.message}")
      fallback_payload(message)
    end

    def build_messages(message, history)
      messages = [{ role: 'system', content: system_prompt }]
      normalize_history(history).each { |turn| messages << turn }
      messages << { role: 'user', content: message.to_s }
      messages
    end

    def normalize_history(history)
      Array(history).filter_map do |item|
        item = item.to_h.with_indifferent_access if item.respond_to?(:to_h)
        role = item[:role].to_s
        content = item[:content].to_s.strip
        next unless %w[user assistant].include?(role)
        next if content.blank?

        { role: role, content: content.truncate(800) }
      end.last(HISTORY_LIMIT)
    end

    def synthesize_reply_audio(text)
      return nil if text.blank?

      audio_data = TtsService.new(
        text: text.to_s.truncate(900),
        voice: 'alloy',
        language: @language
      ).generate_speech

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(audio_data),
        filename: "deal_reply_#{SecureRandom.hex(8)}.mp3",
        content_type: 'audio/mpeg'
      )
      Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    rescue => e
      Rails.logger.warn("ConversationService TTS skipped: #{e.message}")
      nil
    end

    def system_prompt
      summary = @deal.deal_summary
      pages_context = @deal.deal_pages.order(:page_number).map do |p|
        "P#{p.page_number} #{p.title}: #{p.script.to_s.truncate(300)}"
      end.join("\n")

      user_context = if @user_progress
        user = @user_progress.user
        parts = [
          ("参加者: #{user&.name}" if user&.name.present?),
          ("役職: #{user.job_title}" if user&.job_title.present?),
          ("会社: #{user.company}" if user&.company.present?),
          ("検討フェーズ: #{@user_progress.consideration_phase}")
        ].compact
        parts.join(', ')
      else
        ''
      end

      if @language == 'ja'
        <<~PROMPT
          あなたは「#{@deal.title}」のAI商談アシスタントです。
          資料に基づき、丁寧で具体的に回答してください。資料にない内容は推測せず、その旨を伝えてください。
          回答は200字以内を目安に、次の質問を促す一文で締めてください。
          直前の会話の流れを踏まえ、同じ説明の繰り返しを避けてください。

          #{phase_guidance}

          【商談要約】
          #{summary&.summary}
          #{summary&.key_points}

          【スライド台本】
          #{pages_context}

          【FAQ（承認済み）】
          #{faq_context}

          #{user_context}
        PROMPT
      else
        <<~PROMPT
          You are the AI sales assistant for "#{@deal.title}".
          Answer based on the materials. Do not invent facts.
          Keep continuity with prior turns and avoid repeating the same explanation.

          #{phase_guidance}

          Summary: #{summary&.summary}
          Slides: #{pages_context}
          FAQ: #{faq_context}
          #{user_context}
        PROMPT
      end
    end

    def phase_guidance
      phase = @user_progress&.consideration_phase.to_s
      if @language == 'ja'
        case phase
        when 'initial', 'information_gathering'
          '【話し方】情報収集段階です。概要・価値・差別化をわかりやすく。押し売りせず、関心のある点を引き出してください。'
        when 'evaluation'
          '【話し方】比較検討段階です。料金・導入手順・効果の根拠を具体的に。懸念を先回りして解消してください。'
        when 'decision'
          '【話し方】意思決定段階です。次の一歩（トライアル・担当者商談・契約）を明確に提案してください。'
        else
          '【話し方】相手の検討度合いに合わせ、丁寧で簡潔に案内してください。'
        end
      else
        case phase
        when 'initial', 'information_gathering'
          'Tone: discovery stage. Clarify value without hard selling.'
        when 'evaluation'
          'Tone: evaluation stage. Be concrete on pricing, onboarding, and proof.'
        when 'decision'
          'Tone: decision stage. Propose a clear next step.'
        else
          'Tone: polite and concise.'
        end
      end
    end

    def faq_context
      context = @deal.faq_context_for_prompt
      return (@language == 'ja' ? '（未設定）' : '(none)') if context.blank?

      context
    end

    def fallback_payload(message)
      {
        type: 'ai',
        text: fallback_response(message),
        audio_url: nil,
        follow_up: follow_up_prompt
      }
    end

    def fallback_response(message)
      if @language == 'ja'
        "ご質問「#{message.to_s.truncate(50)}」について、資料の範囲内でお答えします。#{@deal.deal_summary&.summary.to_s.truncate(150)} 他にも知りたい点があればお知らせください。"
      else
        "Regarding your question, here's what I can share based on our materials: #{@deal.deal_summary&.summary.to_s.truncate(150)}"
      end
    end

    def follow_up_prompt
      @language == 'ja' ? '他に知りたいトピックはありますか？メニューから選ぶか、自由にご質問ください。' : 'Would you like to explore another topic?'
    end

    def audio_url_for(attachment)
      return nil unless attachment&.attached?

      Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
    end
  end
end
