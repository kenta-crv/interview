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
          以下の商談資料要約に基づき、AI商談の冒頭3パートと締め1パートの読み上げ台本を作成してください。
          冒頭各パートは80〜120字程度、締めは120〜180字程度。丁寧なビジネス日本語で。

          【資料要約】
          #{context.truncate(4000)}

          JSONのみ出力:
          {
            "greeting": "挨拶（会社名は#{@deal.title}）",
            "company_overview": "会社・サービス概要",
            "usage_guide": "進め方の3択案内。必ず次を含める: (1)気になる点を自由に質問 (2)下のメニューからトピックを選ぶ (3)ご指定がない場合はこのまま進行",
            "closing": "営業クロージング。魅力・価値を短く再提示し、契約またはトライアル、もしくは担当者への詳細案内を促す"
          }
        PROMPT
      else
        <<~PROMPT
          Based on this deal summary, create 3 opening narration scripts (80-120 words each)
          and 1 closing sales script (120-180 words).
          Write ALL scripts in English, even if the source materials are Japanese.

          Summary:
          #{context.truncate(4000)}

          Output JSON only:
          {
            "greeting": "Greeting (company/deal name: #{@deal.title})",
            "company_overview": "Company / service overview",
            "usage_guide": "How to proceed. Must include these 3 options: (1) ask free-form questions (2) pick a topic from the menu below (3) if unspecified, continue through the materials",
            "closing": "Sales closing that briefly restates value and invites contract/trial or a follow-up with a human rep"
          }
        PROMPT
      end

      result = parse_json_response(call_claude(prompt), default_opening_scripts)
      @deal.update!(
        greeting_script: result['greeting'] || result[:greeting],
        company_overview_script: result['company_overview'] || result[:company_overview],
        usage_guide_script: result['usage_guide'] || result[:usage_guide],
        closing_script: result['closing'] || result[:closing] || default_opening_scripts['closing']
      )
    end

    def append_role_closings!
      @deal.deal_pages.order(:page_number).each do |page|
        role = @deal.page_role_for(page)
        next unless role

        suffix = @deal.role_closing_text_for(role)
        next if suffix.blank?
        next if page.script.to_s.include?(Deal::ROLE_CLOSING_MARKER)

        base = page.script.to_s.strip
        next if base.blank?

        page.update!(script: "#{base}\n\n#{suffix}")
      end
    end

    def generate_menu_items!
      pages = @deal.deal_pages.order(:page_number)
      return if pages.empty?

      page_data = pages.map do |p|
        { page_number: p.page_number, title: p.title, script: p.script.to_s.truncate(200) }
      end

      prompt = if @language == 'ja'
        <<~PROMPT
          以下のスライド一覧から、商談参加者が選べるメニューを作成してください。

          ルール:
          - 表紙・挨拶のみのスライドを除き、内容のあるスライドをできるだけ多くメニュー化する（目安: 6〜12件、ページ数に応じて増減）
          - label は各スライドの要点を短く表す（例: 会社概要、受入実績、料金、サポート体制、導入フロー、USP）
          - key は可能な限り英語スネークケース（pricing / flow / overview など）
          - 料金・プラン系は key を pricing、導入・契約フロー系は key を flow にする
          - 「前半」「中盤」「後半」のような抽象ラベルは禁止
          - 表紙・挨拶のみのスライドはメニューに含めない
          - 各メニューは対応する page_number を必ず含める
          - menu_items は page_number の昇順で並べる（小さいページ番号が先）

          【スライド一覧】
          #{page_data.to_json}

          JSONのみ出力:
          {"menu_items":[{"key":"company_overview","label":"会社概要","page_number":2}]}
        PROMPT
      else
        <<~PROMPT
          Create menu items for as many substantive slides as practical (about 6-12, excluding cover/greeting-only). Each item must include page_number.
          Write every label in English, even if slide titles are Japanese.
          Order menu_items by ascending page_number.
          Prefer concrete labels (overview, pricing, support, flow). Avoid abstract labels like "first half".

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
          'usage_guide' => '進め方は3つです。1つ目は、気になる点を自由にご質問ください。2つ目は、下のメニューから知りたいトピックを選んでください。3つ目は、ご指定がない場合、このまま進行させていただきます。',
          'closing' => @deal.default_closing_text
        }
      else
        {
          'greeting' => "Hello. I'm the AI sales assistant for #{@deal.title}. Thank you for your time today.",
          'company_overview' => @deal.deal_summary&.summary.presence || @deal.description.presence || "I'll walk you through our proposal based on the uploaded materials.",
          'usage_guide' => 'There are three ways to proceed. First, ask any questions freely. Second, choose a topic from the menu below. Third, if you do not specify, I will continue through the materials in order.',
          'closing' => @deal.default_closing_text
        }
      end
    end

    def fallback_menu_items(pages)
      {
        'menu_items' => pages.reject { |p| p.page_number == 1 && p.title.to_s.match?(/表紙|挨拶|cover/i) }.map do |page|
          {
            'key' => "page_#{page.page_number}",
            'label' => page.title.presence || slide_fallback_label(page.page_number),
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

        key = (item['key'] || item[:key] || "page_#{page.page_number}").to_s
        haystack = "#{key} #{label} #{page.title}"
        if haystack.match?(/料金|費用|価格|プラン|月額|pricing|price|plan/i)
          key = 'pricing'
        elsif haystack.match?(/導入|フロー|手順|オンボーディング|契約フロー|flow|onboard/i)
          key = 'flow'
        end

        {
          'key' => key,
          'label' => label.presence || page.title.presence || slide_fallback_label(page.page_number),
          'page_number' => page.page_number
        }
      end.sort_by { |item| item['page_number'].to_i }
    end

    def slide_fallback_label(page_number)
      @language == 'ja' ? "スライド #{page_number}" : "Slide #{page_number}"
    end
  end
end
