module DealEngine
  class SessionAnalysisService
    MODEL = 'gpt-5.4-nano'
    GRADES = {
      80 => 'A',
      60 => 'B',
      40 => 'C',
      0 => 'D'
    }.freeze

    def self.call(user_progress:)
      new(user_progress: user_progress).call
    end

    def initialize(user_progress:)
      @user_progress = user_progress
      @deal = user_progress.deal
      @events = @deal.deal_presentation_events.where(user_id: user_progress.user_id).order(:occurred_at)
    end

    def call
      score = compute_score
      grade = grade_for(score)
      summary = generate_summary(score: score, grade: grade)

      @user_progress.update!(
        prospect_score: score,
        prospect_grade: grade,
        session_summary: summary,
        session_analyzed_at: Time.current
      )

      { score: score, grade: grade, summary: summary }
    end

    private

    def compute_score
      score = phase_score
      score += duration_score
      score += [topic_clicks * 5, 20].min
      score += [free_text_count * 5, 20].min
      score += [unique_pages * 3, 15].min
      score += 25 if cta_engaged?
      score += evaluation_bonus
      score.clamp(0, 100)
    end

    def phase_score
      case @user_progress.consideration_phase.to_s
      when 'decision' then 55
      when 'evaluation' then 40
      when 'information_gathering' then 25
      when 'initial' then 10
      else 15
      end
    end

    def duration_score
      close = @events.where(event_type: 'session_close').last
      ms = close&.metadata.is_a?(Hash) ? close.metadata['duration_ms'].to_i : 0
      return 5 if ms <= 0

      minutes = ms / 60_000.0
      case minutes
      when 0...1 then 5
      when 1...3 then 10
      when 3...8 then 15
      else 20
      end
    end

    def topic_clicks
      @events.where(event_type: 'topic_click').count
    end

    def free_text_count
      @events.where(event_type: 'free_text_send').count
    end

    def unique_pages
      @events.where(event_type: %w[page_view topic_click]).where.not(page_number: nil).distinct.count(:page_number)
    end

    def cta_engaged?
      @events.where(event_type: %w[cta_click exit_contract_click exit_sales_call_click]).exists?
    end

    def evaluation_bonus
      evaluation = @deal.deal_evaluations.find_by(user_id: @user_progress.user_id)
      return 0 unless evaluation

      evaluation.rating.to_i * 2
    end

    def grade_for(score)
      GRADES.find { |threshold, _| score >= threshold }&.last || 'D'
    end

    def generate_summary(score:, grade:)
      llm_summary = llm_summary_payload
      {
        'challenge' => llm_summary['challenge'].presence || fallback_challenge,
        'interest' => llm_summary['interest'].presence || fallback_interest,
        'consideration' => llm_summary['consideration'].presence || fallback_consideration,
        'next_action' => llm_summary['next_action'].presence || fallback_next_action,
        'score' => score,
        'grade' => grade,
        'topics' => interested_topics,
        'questions' => recent_questions
      }
    end

    def llm_summary_payload
      api_key = ENV['OPENAI_API_KEY']
      return {} if api_key.blank?

      uri = URI.parse('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 45

      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{api_key}"
      request.body = {
        model: MODEL,
        messages: [
          { role: 'system', content: summary_system_prompt },
          { role: 'user', content: summary_user_prompt }
        ],
        max_completion_tokens: 500,
        temperature: 0.3
      }.to_json

      response = http.request(request)
      body = JSON.parse(response.body)
      content = body.dig('choices', 0, 'message', 'content').to_s
      parse_json_object(content)
    rescue => e
      Rails.logger.error("SessionAnalysisService LLM error: #{e.message}")
      {}
    end

    def summary_system_prompt
      <<~PROMPT
        あなたはBtoB商談の分析アシスタントです。
        操作ログから見込み客の状態を要約し、次のJSONのみを返してください。
        {"challenge":"...","interest":"...","consideration":"...","next_action":"..."}
        各値は日本語で40字以内。推測しすぎないこと。
      PROMPT
    end

    def summary_user_prompt
      <<~PROMPT
        商談: #{@deal.title}
        検討フェーズ: #{@user_progress.consideration_phase}
        導入予定: #{@user_progress.planned_introduction_date}
        重要ポイント: #{@user_progress.key_points_for_application}
        見たトピック: #{interested_topics.join(' / ').presence || 'なし'}
        質問: #{recent_questions.join(' / ').presence || 'なし'}
        CTA: #{cta_engaged? ? 'あり' : 'なし'}
        イベント概要:
        #{event_digest}
      PROMPT
    end

    def event_digest
      @events.last(40).map do |event|
        parts = [event.event_type]
        parts << "p#{event.page_number}" if event.page_number.present?
        parts << (event.label.presence || event.topic)
        parts << event.message.to_s.truncate(80) if event.message.present?
        parts.compact.join(' | ')
      end.join("\n")
    end

    def interested_topics
      @events.where(event_type: 'topic_click').filter_map { |e| e.label.presence || e.topic }.uniq.first(5)
    end

    def recent_questions
      @events.where(event_type: 'free_text_send').filter_map { |e| e.message.presence }.last(5)
    end

    def fallback_challenge
      @user_progress.key_points_for_application.presence&.truncate(40) || '課題はログから特定できず'
    end

    def fallback_interest
      interested_topics.first(2).join('・').presence || '関心トピックはまだ少ない'
    end

    def fallback_consideration
      phase = @user_progress.consideration_phase.to_s
      {
        'initial' => '初期情報収集',
        'information_gathering' => '情報収集中',
        'evaluation' => '比較検討中',
        'decision' => '導入判断中'
      }[phase] || '検討状況は未申告'
    end

    def fallback_next_action
      return '担当者商談または契約導線へ案内' if cta_engaged?
      return '追加質問への回答とフォローメール' if free_text_count.positive?
      return '主要トピックの再案内' if topic_clicks.positive?

      'フォローメールで再接点を作る'
    end

    def parse_json_object(content)
      json_text = content[/\{\s*".*\}\s*/m]
      return {} if json_text.blank?

      JSON.parse(json_text)
    rescue JSON::ParserError
      {}
    end
  end
end
