require "net/http"
require "json"
require "openssl"

class GptPillarGenerator
  MODEL_NAME = "gpt-4o-mini"
  GPT_API_URL = "https://api.openai.com/v1/chat/completions"

  GENRE_REVERSE_MAP = {
    "cargo"        => "軽貨物",
    "cleaning"     => "清掃業",
    "security"     => "警備業",
    "app"          => "営業代行",
    "vender"       => "自販機",
    "construction" => "建設"
  }.freeze

  GENRE_MAP = {
    "軽貨物"   => "cargo",
    "清掃業"   => "cleaning",
    "警備業"   => "security",
    "営業代行" => "app",
    "自販機"   => "vender",
    "建設"     => "construction"
  }.freeze

  CATEGORY_KEYWORDS = {
    "警備業"   => ["警備", "セキュリティー", "施設警備", "交通整理"],
    "軽貨物"   => ["軽貨物", "配送", "運送", "ドライバー", "宅配"],
    "清掃業"   => ["清掃", "クリーニング", "ハウスクリーニング", "ビル清掃"],
    "自販機"   => ["自動販売機設置", "自販機設置", "自販機経営"],
    "営業代行" => ["営業代行", "テレアポ代行", "インサイドセールス", "法人リスト制作", "フォーム営業", "商談代行"],
    "建設"     => ["建設", "現場", "工務店", "リフォーム", "土木"]
  }.freeze

  def self.generate_full_from_existing_column!(column)
    raise "タイトルが空です" if column.title.blank?

    target_category = GENRE_REVERSE_MAP[column.genre] || detect_category(column)
    genre_code = GENRE_MAP[target_category] || "other"

    puts "▶ 統合生成開始: #{column.title} (判定: #{target_category})"

    meta_data = generate_meta_info(column, target_category)
    raise "Meta情報の生成に失敗しました" if meta_data.nil?

    clean_code = meta_data["code"].to_s.downcase
      .gsub(/[^a-z0-9\s\-]/, '')
      .strip
      .gsub(/[\s_]+/, '-')
      .gsub(/-+/, '-')
      .gsub(/\A-|-\z/, '')
    clean_code = "article-#{column.id.to_s.split('-').first}" if clean_code.blank?

    structure_data = generate_structure(column, target_category)
    raise "記事構成の生成に失敗しました" if structure_data.nil? || structure_data["structure"].nil?

    column.update!(
      code: clean_code,
      description: meta_data["description"],
      keyword: meta_data["keyword"],
      genre: genre_code,
      status: "creating",
      article_type: "pillar"
    )

    h2_titles = structure_data["structure"].map { |s| s["h2_title"] }
    body_content = ""

    body_content += call_text_section(
      introduction_prompt(column, target_category, h2_titles)
    ) + "\n\n"

    structure_data["structure"].each_with_index do |section, index|
      prev_h2 = index > 0 ? h2_titles[index - 1] : nil
      next_h2 = h2_titles[index + 1]

      body_content += "## #{section["h2_title"]}\n\n"
      body_content += call_text_section(
        h2_content_prompt(column, target_category, section, prev_h2, next_h2)
      ) + "\n\n"
      sleep(1.0)
    end

    body_content += call_text_section(conclusion_prompt(column, target_category))
    body_content += "\n\n{::options auto_ids=\"false\" /}"

    column.update!(body: body_content, status: "completed")
    puts "✅ 生成完了: #{clean_code}"
    true
  end

  private

  def self.detect_category(column)
    search_text = "#{column.title} #{column.keyword} #{column.genre} #{column.choice}"
    CATEGORY_KEYWORDS.each do |category, words|
      return category if words.any? { |w| search_text.include?(w) }
    end
    "その他"
  end

  def self.generate_meta_info(column, category)
    prompt = <<~PROMPT
      以下の条件でSEOメタ情報をJSONで生成してください。
      タイトル: #{column.title}
      業種: #{category}
      形式: { "code": "slug", "description": "日本語説明", "keyword": "キーワード" }
    PROMPT

    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.generate_structure(column, category)
    child_titles = Column.where(parent_id: column.id, article_type: "child").pluck(:title).join(", ")

    prompt = <<~PROMPT
      記事「#{column.title}」の構成案を作成してください。
      業種: #{category}
      読者が「実際に業務を始めるための手順」を理解できるよう、
      準備 → 実行 → 注意点 → よくある失敗 → 成果を出すコツ
      という流れでH2見出しを6〜8個作成してください。
      参考子記事: #{child_titles}
      出力形式: { "structure": [ { "h2_title": "見出し名" } ] }
    PROMPT

    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.call_text_section(prompt)
    response = call_gpt_api(prompt, json_mode: false)
    content = response&.dig("choices", 0, "message", "content")
    content.present? ? content.strip : "（生成エラー）"
  end

  def self.call_gpt_api(prompt, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{ENV['GPT_API_KEY']}"

    system_content = "あなたは業種特化型のプロSEOライターです。抽象論は禁止し、現場で実際に行われている具体的な業務内容のみを書いてください。"
    system_content += " 出力はJSON形式のみ。" if json_mode
    system_content += " Markdown形式の本文テキストのみを出力してください。" unless json_mode

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: system_content },
        { role: "user", content: prompt }
      ],
      temperature: 0.4
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 240) do |http|
      http.request(req)
    end
    JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)
  rescue
    nil
  end

  def self.introduction_prompt(column, category, h2_titles)
    <<~PROMPT
      記事「#{column.title}」の導入文を600文字以上で執筆してください。
      業種: #{category}
      この記事で解説する内容は次の流れです。
      #{h2_titles.join(" → ")}
      読者が「この業種で何をどう始めればよいか」を具体的に理解できる導入文にしてください。
    PROMPT
  end

  def self.h2_content_prompt(column, category, section, prev_h2, next_h2)
    context = ""
    context += "前の見出し「#{prev_h2}」の内容を自然に受けて書き始めてください。" if prev_h2
    context += "最後は次の見出し「#{next_h2}」につながる形で締めてください。" if next_h2

    <<~PROMPT
      見出し「#{section["h2_title"]}」について1000文字前後で執筆してください。
      業種: #{category}
      抽象的な精神論は禁止です。
      実際の作業手順、必要な道具、現場で起こりやすいトラブル、具体例を中心に解説してください。
      #{context}
    PROMPT
  end

  def self.conclusion_prompt(column, category)
    <<~PROMPT
      記事「#{column.title}」の締めくくりとして総括文を執筆してください。
      「## まとめ」という見出しから開始してください。
      本記事で解説した内容を簡潔に振り返り、
      読者が次に取るべき具体的な行動が明確になるようにまとめてください。
    PROMPT
  end
end
