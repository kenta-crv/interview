# frozen_string_literal: true

require "set"

module DealEngine
  # 公開URL〜セッション〜追客までのファネル指標を集計する
  class AnalyticsSummaryService
    CTA_EVENT_TYPES = %w[cta_click exit_contract_click exit_sales_call_click].freeze

    def self.call(deal_ids:)
      new(deal_ids: deal_ids).call
    end

    def initialize(deal_ids:)
      @deal_ids = Array(deal_ids).compact.uniq
    end

    def call
      empty_summary.tap do |summary|
        return summary if @deal_ids.empty?

        summary.merge!(core_counts)
        summary.merge!(event_metrics)
        summary.merge!(follow_up_metrics)
        summary.merge!(rate_metrics(summary))
      end
    end

    private

    def empty_summary
      {
        page_views: 0,
        leads_count: 0,
        sessions_started: 0,
        sessions_completed: 0,
        lead_rate: nil,
        start_rate: nil,
        completion_rate: nil,
        prospect_grade_counts: { "A" => 0, "B" => 0, "C" => 0, "D" => 0 },
        high_prospect_count: 0,
        average_evaluation: nil,
        evaluation_count: 0,
        cta_clicks: 0,
        follow_up_sent: 0,
        follow_up_opened: 0,
        follow_up_clicked: 0,
        average_duration_ms: nil,
        average_duration_label: "—",
        drop_offs: [],
        funnel_segments: []
      }
    end

    def core_counts
      progresses = UserProgress.where(deal_id: @deal_ids)
      grade_counts = progresses.where.not(prospect_grade: nil).group(:prospect_grade).count
      grades = { "A" => 0, "B" => 0, "C" => 0, "D" => 0 }.merge(grade_counts)
      evaluations = DealEvaluation.where(deal_id: @deal_ids)

      {
        page_views: Deal.where(id: @deal_ids).sum(:page_views_count),
        leads_count: progresses.count,
        prospect_grade_counts: grades,
        high_prospect_count: grades["A"].to_i + grades["B"].to_i,
        evaluation_count: evaluations.count,
        average_evaluation: evaluations.average(:rating)&.round(1)
      }
    end

    def event_metrics
      rows = DealPresentationEvent
             .where(deal_id: @deal_ids, event_type: %w[presentation_start session_close] + CTA_EVENT_TYPES)
             .pluck(:event_type, :session_key, :page_number, :metadata)

      started_keys = Set.new
      completed_keys = Set.new
      durations = []
      drop_off_counts = Hash.new(0)
      cta_clicks = 0

      rows.each do |event_type, session_key, page_number, metadata|
        meta = normalize_metadata(metadata)
        next if preview?(meta)

        case event_type
        when "presentation_start"
          started_keys << session_key
        when "session_close"
          page = meta["current_page_number"].presence || page_number
          drop_off_counts[page.to_i] += 1 if page.present?
          duration = meta["duration_ms"].to_i
          durations << duration if duration.positive?
          completed_keys << session_key if meta["evaluated"] == true
        when *CTA_EVENT_TYPES
          cta_clicks += 1
        end
      end

      average_ms = durations.any? ? (durations.sum.to_f / durations.size).round : nil

      {
        sessions_started: started_keys.size,
        sessions_completed: completed_keys.size,
        cta_clicks: cta_clicks,
        average_duration_ms: average_ms,
        average_duration_label: format_duration(average_ms),
        drop_offs: build_drop_offs(drop_off_counts)
      }
    end

    def follow_up_metrics
      deliveries = FollowUpDelivery.joins(:user_progress).where(user_progresses: { deal_id: @deal_ids })
      sent = deliveries.where(status: %w[sent opened])
      opened = deliveries.where.not(opened_at: nil)
      clicked = deliveries.where(
        "sales_call_clicked_at IS NOT NULL OR contract_clicked_at IS NOT NULL"
      )

      {
        follow_up_sent: sent.count,
        follow_up_opened: opened.count,
        follow_up_clicked: clicked.count
      }
    end

    def rate_metrics(summary)
      {
        lead_rate: percent(summary[:leads_count], summary[:page_views]),
        start_rate: percent(summary[:sessions_started], summary[:leads_count]),
        completion_rate: percent(summary[:sessions_completed], summary[:sessions_started]),
        funnel_segments: build_funnel_segments(summary)
      }
    end

    # 訪問〜完了を相互排他セグメントにし、円グラフ用にする
    def build_funnel_segments(summary)
      views = summary[:page_views].to_i
      leads = summary[:leads_count].to_i
      started = summary[:sessions_started].to_i
      completed = summary[:sessions_completed].to_i

      completed = [completed, 0].max
      started = [started, completed].max
      leads = [leads, started].max
      views = [views, leads].max

      raw = [
        { key: "visit_only", label: "訪問のみ", count: views - leads, color: "#94a3b8" },
        { key: "lead_only", label: "登録のみ", count: leads - started, color: "#c9a227" },
        { key: "started_only", label: "開始のみ", count: started - completed, color: "#2f9e6b" },
        { key: "completed", label: "完了", count: completed, color: "#4f6bed" }
      ]

      total = raw.sum { |row| row[:count] }
      return [] if total.zero?

      cursor = 0.0
      raw.filter_map do |row|
        next if row[:count].zero?

        share = ((row[:count].to_f / total) * 100).round(1)
        start_pct = cursor.round(2)
        cursor = (cursor + share).round(2)
        end_pct = [cursor, 100.0].min
        row.merge(share: share, start_pct: start_pct, end_pct: end_pct)
      end
    end

    def build_drop_offs(counts)
      return [] if counts.empty?

      page_titles = DealPage.where(deal_id: @deal_ids).pluck(:page_number, :title).to_h
      total = counts.values.sum.to_f

      counts.sort_by { |page, count| [-count, page] }.map do |page, count|
        {
          page_number: page,
          title: page_titles[page].presence || "ページ#{page}",
          count: count,
          share: total.positive? ? ((count / total) * 100).round(1) : 0.0
        }
      end
    end

    def normalize_metadata(metadata)
      case metadata
      when Hash
        metadata
      when String
        JSON.parse(metadata)
      else
        {}
      end
    rescue JSON::ParserError
      {}
    end

    def preview?(meta)
      meta.is_a?(Hash) && (meta["preview"] == true || meta[:preview] == true)
    end

    def percent(numerator, denominator)
      return nil if denominator.to_i <= 0

      ((numerator.to_f / denominator) * 100).round(1)
    end

    def format_duration(ms)
      return "—" if ms.blank?

      seconds = (ms / 1000.0).round
      return "#{seconds}秒" if seconds < 60

      minutes = seconds / 60
      remain = seconds % 60
      remain.zero? ? "#{minutes}分" : "#{minutes}分#{remain}秒"
    end
  end
end
