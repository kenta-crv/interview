require 'pdf-reader'

module DealEngine
  class ScriptGeneratorService
    def initialize(deal)
      @deal = deal
      @language = deal.language || 'ja'
    end

    def generate_page_script(page_number:, page_text:, total_pages:)
      cleaned = page_text.to_s.strip
      return fallback_page_script(page_number) if cleaned.blank?

      prompt = if @language == 'ja'
        <<~PROMPT
          あなたはBtoB商談のプレゼン担当です。以下のスライド（#{page_number}/#{total_pages}ページ目）の内容を、
          そのまま読み上げられる自然な日本語ナレーション（150〜250字）に変換してください。
          箇条書きは口語に直し、聞き手に語りかけるトーンにしてください。

          【スライド原文】
          #{cleaned.truncate(3000)}

          JSONのみ出力（説明不要）:
          {"title":"スライドの短いタイトル","script":"読み上げ台本"}
        PROMPT
      else
        <<~PROMPT
          You are a B2B sales presenter. Convert slide #{page_number}/#{total_pages} into natural spoken narration (150-250 words).

          Slide text:
          #{cleaned.truncate(3000)}

          Output JSON only:
          {"title":"Short slide title","script":"Narration script"}
        PROMPT
      end

      parse_json_response(call_claude(prompt), fallback_page_script(page_number))
    end

    def generate_opening_scripts!
      summary = @deal.deal_summary
      return unless summary

      context = [
        summary.summary,
        summary.key_points
      ].join("\n")

      prompt = if @language == 'ja'
        <<~PROMPT
          以下の商談資料要約に基づき、AI商談の冒頭3パートの読み上げ台本を作成してください。
          各パートは80〜120字程度、丁寧なビジネス日本語で。

          【資料要約】
          #{context.truncate(4000)}

          JSONのみ出力:
          {
            "greeting": "挨拶（会社名は#{@deal.title}）",
            "company_overview": "会社・サービス概要",
            "usage_guide": "メニューからトピックを選ぶ案内"
          }
        PROMPT
      else
        <<~PROMPT
          Based on this deal summary, create 3 opening narration scripts (80-120 words each).

          Summary:
          #{context.truncate(4000)}

          Output JSON only:
          {"greeting":"...","company_overview":"...","usage_guide":"..."}
        PROMPT
      end

      result = parse_json_response(call_claude(prompt), default_opening_scripts)
      @deal.update!(
        greeting_script: result['greeting'] || result[:greeting],
        company_overview_script: result['company_overview'] || result[:company_overview],
        usage_guide_script: result['usage_guide'] || result[:usage_guide]
      )
    end

    def generate_menu_items!
      pages = @deal.deal_pages.order(:page_number)
      return if pages.empty?

      page_data = pages.map do |p|
        { page_number: p.page_number, title: p.title, script: p.script.to_s.truncate(200) }
      end

      prompt = if @language == 'ja'
        <<~PROMPT
          以下のスライド一覧から、商談参加者が選べるメニュー（3〜6件）を作成してください。

          ルール:
          - label は各スライドの要点を短く表す（例: 会社概要、受入実績、料金、サポート体制、導入フロー、USP）
          - 「前半」「中盤」「後半」のような抽象ラベルは禁止
          - 表紙・挨拶のみのスライドはメニューに含めない
          - 各メニューは対応する page_number を必ず含める

          【スライド一覧】
          #{page_data.to_json}

          JSONのみ出力:
          {"menu_items":[{"key":"company_overview","label":"会社概要","page_number":2}]}
        PROMPT
      else
        <<~PROMPT
          Create 3-6 menu items from these slides. Each item must include page_number.

          Slides:
          #{page_data.to_json}

          Output JSON only:
          {"menu_items":[{"key":"overview","label":"Label","page_number":1}]}
        PROMPT
      end

      result = parse_json_response(call_claude(prompt), fallback_menu_items(pages))
      items = result['menu_items'] || result[:menu_items] || fallback_menu_items(pages)['menu_items']
      @deal.update!(menu_items: normalize_menu_items(items, pages))
    end

    def rewrite_script(original_script, instruction: nil)
      original_script = original_script.to_s.strip
      if original_script.blank?
        return @language == 'ja' ? '内容を確認中です。しばらくお待ちください。' : 'Content is being prepared.'
      end

      instruction ||= @language == 'ja' ? 'より自然で聞きやすい商談台本に改善してください' : 'Improve for natural spoken delivery'

      prompt = if @language == 'ja'
        <<~PROMPT
          以下の商談台本を、指示に従って書き直してください。

          【指示】#{instruction}

          【元の台本】
          #{original_script}

          JSONのみ出力: {"script":"書き直した台本"}
        PROMPT
      else
        <<~PROMPT
          Rewrite this script per instruction: #{instruction}

          Original:
          #{original_script}

          Output JSON only: {"script":"..."}
        PROMPT
      end

      result = parse_json_response(call_claude(prompt), { 'script' => original_script })
      result['script'] || result[:script] || original_script
    end

    def extract_page_text(pdf_path, page_number)
      reader = PDF::Reader.new(pdf_path)
      reader.page(page_number).text.to_s.strip
    rescue => e
      Rails.logger.warn("Page text extraction failed p#{page_number}: #{e.message}")
      ''
    end

    private

    def call_claude(prompt)
      api_key = ENV['ANTHROPIC_API_KEY']
      return '' if api_key.blank?

      uri = URI.parse('https://api.anthropic.com/v1/messages')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 120

      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = api_key
      request['anthropic-version'] = '2023-06-01'
      request.body = {
        model: 'claude-sonnet-4-5-20250929',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }]
      }.to_json

      response = http.request(request)
      body = JSON.parse(response.body)
      body.dig('content', 0, 'text').to_s
    rescue => e
      Rails.logger.error("ScriptGenerator Claude error: #{e.message}")
      ''
    end

    def parse_json_response(text, fallback)
      cleaned = text.to_s.gsub(/```json\s*/i, '').gsub(/```/, '').strip
      return fallback if cleaned.blank?

      JSON.parse(cleaned)
    rescue JSON::ParserError
      fallback
    end

    def fallback_page_script(page_number)
      if @language == 'ja'
        {
          'title' => "#{page_number}ページ目",
          'script' => "#{page_number}ページ目についてご説明します。このスライドには提案の重要なポイントが含まれています。"
        }
      else
        {
          'title' => "Page #{page_number}",
          'script' => "Let me explain page #{page_number}. This slide covers important points in our proposal."
        }
      end
    end

    def default_opening_scripts
      if @language == 'ja'
        {
          'greeting' => "こんにちは。#{@deal.title}のAI商談アシスタントです。本日はお時間をいただきありがとうございます。",
          'company_overview' => @deal.deal_summary&.summary.presence || @deal.description.presence || '本日は資料に基づき、サービス内容をご案内いたします。',
          'usage_guide' => '知りたいトピックをメニューからお選びください。自由にご質問いただくこともできます。'
        }
      else
        {
          'greeting' => "Hello. I'm the AI sales assistant for #{@deal.title}. Thank you for your time today.",
          'company_overview' => @deal.deal_summary&.summary.presence || @deal.description.presence || "I'll walk you through our proposal based on the uploaded materials.",
          'usage_guide' => 'Please select a topic from the menu, or type your question freely.'
        }
      end
    end

    def fallback_menu_items(pages)
      {
        'menu_items' => pages.reject { |p| p.page_number == 1 && p.title.to_s.match?(/表紙|挨拶|cover/i) }.first(6).map do |page|
          {
            'key' => "page_#{page.page_number}",
            'label' => page.title.presence || "スライド #{page.page_number}",
            'page_number' => page.page_number
          }
        end
      }
    end

    def normalize_menu_items(items, pages)
      Array(items).filter_map do |item|
        page_number = item['page_number'] || item[:page_number]
        page = pages.find { |p| p.page_number == page_number.to_i }
        next unless page

        label = (item['label'] || item[:label]).to_s
        if label.match?(/前半|中盤|後半|提案内容/)
          label = page.title.presence || label
        end

        {
          'key' => (item['key'] || item[:key] || "page_#{page.page_number}").to_s,
          'label' => label.presence || page.title.presence || "スライド #{page.page_number}",
          'page_number' => page.page_number
        }
      end
    end
  end
end
