module DealFollowUp
  class BodyRenderer
    def initialize(delivery)
      @delivery = delivery
      @user_progress = delivery.user_progress
      @deal = @user_progress.deal
      @user = @user_progress.user
    end

    def subject
      render_text(@delivery.subject)
    end

    def text_body
      [render_text(@delivery.body), personalization_appendix, cta_text_section, unsubscribe_text].compact.join("\n\n")
    end

    def html_body
      paragraphs = render_text(@delivery.body).split(/\n{2,}/).map do |chunk|
        "<p>#{ERB::Util.html_escape(chunk).gsub(/\n/, '<br>')}</p>"
      end.join

      appendix = personalization_appendix
      appendix_html = if appendix.present?
        %(<div style="margin-top:20px;padding:16px;background:#f8fafc;border-radius:8px;"><p style="margin:0;white-space:pre-line;">#{ERB::Util.html_escape(appendix)}</p></div>)
      end

      [paragraphs, appendix_html, cta_html_section, unsubscribe_html].compact.join
    end

    def open_tracking_url
      Rails.application.routes.url_helpers.follow_up_open_url(@delivery.tracking_token, host: default_host)
    end

    private

    def default_host
      ActionMailer::Base.default_url_options[:host] || ENV.fetch("APP_HOST", "localhost:3000")
    end

    def render_text(text)
      summary = @user_progress.session_summary_hash
      text.to_s
          .gsub("{{user_name}}", @user.name.presence || "お客")
          .gsub("{{deal_title}}", @deal.title)
          .gsub("{{company_name}}", @user.company.presence || "")
          .gsub("{{prospect_grade}}", @user_progress.prospect_grade.presence || "-")
          .gsub("{{session_summary}}", @user_progress.session_summary_lines.join("\n").presence || "商談内容を確認中です")
          .gsub("{{interest_topics}}", Array(summary["topics"]).join("、").presence || "ご関心トピック")
          .gsub("{{next_action}}", summary["next_action"].presence || "ご検討のサポート")
    end

    def personalization_appendix
      return nil if @delivery.body.to_s.include?("{{session_summary}}")

      lines = @user_progress.session_summary_lines
      return nil if lines.blank?

      grade = @user_progress.prospect_grade
      header = grade.present? ? "【商談サマリー（見込み度 #{grade}）】" : "【商談サマリー】"
      [header, *lines].join("\n")
    end

    def template
      @delivery.deal_follow_up_template
    end

    def sales_destination_url
      @deal.follow_up_sales_url.presence || @deal.presentation_cta_url.presence || Rails.application.routes.url_helpers.root_url(host: default_host)
    end

    def contract_destination_url
      @deal.presentation_cta_url.presence || Rails.application.routes.url_helpers.root_url(host: default_host)
    end

    def sales_tracking_url
      Rails.application.routes.url_helpers.follow_up_click_url(@delivery.sales_click_token, host: default_host)
    end

    def contract_tracking_url
      Rails.application.routes.url_helpers.follow_up_click_url(@delivery.contract_click_token, host: default_host)
    end

    def unsubscribe_url
      Rails.application.routes.url_helpers.follow_up_unsubscribe_url(@user_progress.follow_up_unsubscribe_token, host: default_host)
    end

    def show_sales_call_link?
      template.include_sales_call_link? && @deal.follow_up_sales_url.present?
    end

    def show_contract_link?
      template.include_contract_link? && @deal.presentation_cta_url.present?
    end

    def cta_text_section
      lines = []
      lines << "担当者に繋ぐ: #{sales_tracking_url}" if show_sales_call_link?
      lines << "契約を進める: #{contract_tracking_url}" if show_contract_link?
      lines.presence&.join("\n")
    end

    def cta_html_section
      buttons = []
      if show_sales_call_link?
        buttons << %(<a href="#{sales_tracking_url}" style="display:inline-block;margin:8px 12px 8px 0;padding:12px 20px;background:#2563eb;color:#fff;text-decoration:none;border-radius:8px;font-weight:700;">担当者に繋ぐ</a>)
      end
      if show_contract_link?
        buttons << %(<a href="#{contract_tracking_url}" style="display:inline-block;margin:8px 0;padding:12px 20px;background:#111827;color:#fff;text-decoration:none;border-radius:8px;font-weight:700;">契約を進める</a>)
      end
      return nil if buttons.empty?

      %(<div style="margin-top:24px;">#{buttons.join}</div>)
    end

    def unsubscribe_text
      "興味がない・導入を見送る場合はこちら: #{unsubscribe_url}"
    end

    def unsubscribe_html
      %(<p style="margin-top:32px;font-size:12px;color:#64748b;"><a href="#{unsubscribe_url}" style="color:#64748b;">興味がない・導入を見送る場合はこちら</a></p>)
    end
  end
end
