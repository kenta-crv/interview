module DealEngine
  class ConversationService
    def initialize(deal, user_progress: nil)
      @deal = deal
      @user_progress = user_progress
      @language = deal.language || 'ja'
    end

    def respond(topic: nil, message: nil, page_number: nil)
      if page_number.present?
        return page_response(page_number.to_i)
      end

      if topic.present?
        menu_item = find_menu_item(topic)
        return page_response(menu_item['page_number']) if menu_item
      end

      free_text = message.presence || topic
      generate_ai_response(free_text)
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

    def generate_ai_response(message)
      api_key = ENV['OPENAI_API_KEY']
      return fallback_response(message) if api_key.blank?

      uri = URI.parse('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{api_key}"
      request.body = {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: message }
        ],
        max_tokens: 800,
        temperature: 0.7
      }.to_json

      response = http.request(request)
      body = JSON.parse(response.body)
      text = body.dig('choices', 0, 'message', 'content') || fallback_response(message)

      {
        type: 'ai',
        text: text,
        audio_url: nil,
        follow_up: follow_up_prompt
      }
    rescue => e
      Rails.logger.error("ConversationService error: #{e.message}")
      { type: 'ai', text: fallback_response(message), audio_url: nil, follow_up: follow_up_prompt }
    end

    def system_prompt
      summary = @deal.deal_summary
      pages_context = @deal.deal_pages.order(:page_number).map do |p|
        "P#{p.page_number} #{p.title}: #{p.script.to_s.truncate(300)}"
      end.join("\n")

      user_context = if @user_progress
        "参加者: #{@user_progress.user&.name}, 検討フェーズ: #{@user_progress.consideration_phase}"
      else
        ''
      end

      if @language == 'ja'
        <<~PROMPT
          あなたは「#{@deal.title}」のAI商談アシスタントです。
          資料に基づき、丁寧で具体的に回答してください。資料にない内容は推測せず、その旨を伝えてください。
          回答は200字以内を目安に、次の質問を促す一文で締めてください。

          【商談要約】
          #{summary&.summary}
          #{summary&.key_points}

          【スライド台本】
          #{pages_context}

          #{user_context}
        PROMPT
      else
        <<~PROMPT
          You are the AI sales assistant for "#{@deal.title}".
          Answer based on the materials. Do not invent facts.

          Summary: #{summary&.summary}
          Slides: #{pages_context}
          #{user_context}
        PROMPT
      end
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

    def error_message(text)
      { type: 'error', text: text, audio_url: nil, follow_up: follow_up_prompt }
    end

    def audio_url_for(attachment)
      return nil unless attachment&.attached?

      Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
    end
  end
end
