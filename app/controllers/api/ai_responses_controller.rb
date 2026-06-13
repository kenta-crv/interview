# app/controllers/api/ai_responses_controller.rb
class Api::AiResponsesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_deal

  def create
    topic = params[:topic]
    response_text = generate_ai_response(topic)

    render json: { response: response_text }
  rescue => e
    render json: { response: fallback_response(topic) }, status: :ok
  end

  private

  def set_deal
    @deal = Deal.find(params[:deal_id])
  end

  def generate_ai_response(topic)
    # OpenAI APIを使用してAI応答を生成
    api_key = ENV['OPENAI_API_KEY']
    return fallback_response(topic) unless api_key

    prompt = build_prompt(topic)

    # 資料の内容を取得
    document_context = build_document_context

    messages = [
      { role: 'system', content: 'あなたはAI商談アシスタントです。丁寧でプロフェッショナルな日本語で回答してください。資料を参照しながら、具体的な説明を行ってください。' },
      { role: 'user', content: prompt }
    ]

    # 資料がある場合はコンテキストに追加
    if document_context.present?
      messages.insert(1, { role: 'system', content: "以下の資料を参照して回答してください：\n\n#{document_context}" })
    end

    uri = URI.parse('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{api_key}"
    request.body = {
      model: 'gpt-4o-mini',
      messages: messages,
      max_tokens: 800,
      temperature: 0.7
    }.to_json

    response = http.request(request)
    body = JSON.parse(response.body)

    if response.code == '200' && body['choices']&.first
      body['choices'].first['message']['content']
    else
      fallback_response(topic)
    end
  rescue => e
    Rails.logger.error("AI response error: #{e.message}")
    fallback_response(topic)
  end

  def build_prompt(topic)
    case topic
    when 'overview'
      'サービス概要について説明してください。AI商談システムの特徴とメリットを教えてください。資料を参照しながら具体的に説明してください。'
    when 'pricing'
      '料金プランについて説明してください。基本プランとオプションについて教えてください。資料を参照しながら具体的に説明してください。'
    when 'trial'
      'トライアルについて説明してください。期間と条件について教えてください。資料を参照しながら具体的に説明してください。'
    when 'contract'
      '契約フローについて説明してください。手続きと必要な書類について教えてください。資料を参照しながら具体的に説明してください。'
    else
      '商談について質問があります。資料を参照しながら回答してください。'
    end
  end

  def build_document_context
    return '' unless @deal.deal_documents.any?

    context = ''
    @deal.deal_documents.each_with_index do |doc, index|
      filename = doc.document.filename.to_s
      context += "【資料#{index + 1}: #{filename}】\n"
      # テキスト抽出は別途実装が必要
      context += "（この資料は商談の参考資料です）\n\n"
    end
    context
  end

  def fallback_response(topic)
    responses = {
      overview: 'サービス概要について説明します。私たちのAI商談システムは、音声認識と要約生成を組み合わせた革新的なソリューションです。商談の記録・分析・共有を効率化し、営業生産性を向上させます。',
      pricing: '料金プランについて説明します。基本プランは月額10,000円から始まり、企業規模に応じた柔軟なプランをご用意しています。チーム規模や機能要件に合わせて最適なプランをご提案いたします。',
      trial: 'トライアルについて説明します。14日間の無料トライアルをご用意しており、すべての機能をお試しいただけます。クレジットカードの登録は不要ですので、お気軽にお試しください。',
      contract: '契約フローについて説明します。オンラインで完結するシンプルな手続きとなっており、最短即日で利用開始可能です。必要な書類は最小限で、スムーズに契約を進められます。'
    }
    responses[topic] || '申し訳ありません、そのトピックについての情報を取得できませんでした。'
  end
end
