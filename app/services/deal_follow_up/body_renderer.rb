module DealFollowUp
  class BodyRenderer
    def initialize(delivery)
      @delivery = delivery
      @user_progress = delivery.user_progress
      @deal = @user_progress.deal
      @user = @user_progress.user
      @summary = @user_progress.session_summary_hash
    end

    def subject
      render_text(@delivery.subject)
    end

    def text_body
      [
        render_text(@delivery.body),
        history_text_section,
        cta_text_section,
        "配信停止: #{unsubscribe_url}"
      ].compact.reject(&:blank?).join("\n\n")
    end

    def html_body
      <<~HTML.gsub(/\n\s*/, "")
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f1f5f9;padding:24px 12px;">
          <tr>
            <td align="center">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="560" style="max-width:560px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e2e8f0;">
                <tr>
                  <td style="background:#0f172a;padding:22px 28px;">
                    <p style="margin:0;font-size:13px;letter-spacing:0.14em;color:#94a3b8;font-family:Arial,sans-serif;">MEETIA</p>
                    <p style="margin:8px 0 0;font-size:20px;line-height:1.4;color:#ffffff;font-weight:700;font-family:Arial,sans-serif;">#{h(@deal.title)} — 商談フォロー</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:28px 28px 8px;font-family:Arial,'Hiragino Sans','Hiragino Kaku Gothic ProN',Meiryo,sans-serif;color:#0f172a;">
                    #{greeting_html}
                    #{history_html_section}
                    #{appeal_html}
                    #{cta_html_section}
                  </td>
                </tr>
                <tr>
                  <td style="padding:8px 28px 28px;font-family:Arial,sans-serif;">
                    <p style="margin:24px 0 0;font-size:11px;line-height:1.6;color:#94a3b8;">このメールは「#{h(@deal.title)}」のAI商談にご参加いただいた方へお送りしています。</p>
                    <p style="margin:10px 0 0;font-size:10px;line-height:1.4;"><a href="#{unsubscribe_url}" style="color:#cbd5e1;text-decoration:underline;">配信停止</a></p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      HTML
    end

    def open_tracking_url
      Rails.application.routes.url_helpers.follow_up_open_url(
        @delivery.tracking_token,
        host: default_host,
        protocol: default_protocol
      )
    end

    private

    def h(text)
      ERB::Util.html_escape(text.to_s)
    end

    def default_host
      ActionMailer::Base.default_url_options[:host].presence || ENV.fetch("APP_HOST", "meetia.pro")
    end

    def default_protocol
      ActionMailer::Base.default_url_options[:protocol].presence || (Rails.env.development? ? "http" : "https")
    end

    def render_text(text)
      text.to_s
          .gsub("{{user_name}}", @user.name.presence || "お客")
          .gsub("{{deal_title}}", @deal.title.to_s)
          .gsub("{{company_name}}", @user.company.presence || "")
          .gsub("{{prospect_grade}}", "")
          .gsub("{{session_summary}}", "")
          .gsub("{{interest_topics}}", topic_labels.join("、").presence || "ご検討内容")
          .gsub("{{next_action}}", customer_offer.presence || "担当者からの個別ご案内")
          .gsub(/\n{3,}/, "\n\n")
          .gsub(/[ \t]+\n/, "\n")
          .strip
    end

    def greeting_html
      chunks = render_text(@delivery.body).split(/\n{2,}/).reject(&:blank?)
      chunks.map do |chunk|
        %(<p style="margin:0 0 16px;font-size:15px;line-height:1.8;color:#1e293b;">#{h(chunk).gsub(/\n/, '<br>')}</p>)
      end.join
    end

    # 顧客開示の境界:
    # 出してよい = 顧客自身が選んだトピック名、顧客が登録した決め手、価値の案内文
    # 出さない  = 課題/検討/見込み度、行動分析の「進み具合」、質問の原文転載、社内向け次アクション
    def topic_labels
      Array(@summary["topics"]).map(&:presence).compact.uniq.first(5)
    end

    def stated_priority
      text = @user_progress.key_points_for_application.to_s.strip
      return nil if text.blank?

      text.truncate(40)
    end

    def customer_offer
      topics = topic_labels
      if topics.any? { |t| t.match?(/料金|価格|プラン|費用|コスト/) }
        return "料金・プランについて、担当者より詳しくご案内できます"
      end
      if topics.any? { |t| t.match?(/機能|デモ|使い方|導入/) }
        return "ご確認いただいた機能について、導入イメージをご案内できます"
      end
      if stated_priority.present?
        return "「#{stated_priority}」を踏まえ、担当者より個別にご案内できます"
      end
      if topics.present?
        return "ご確認いただいた内容の続きを、担当者よりご案内できます"
      end

      "ご不明点の解消から契約のご相談まで、担当者が対応します"
    end

    def history_items
      items = topic_labels.map { |t| { label: "ご確認", value: t } }
      if stated_priority.present?
        items << { label: "ご関心", value: stated_priority }
      end
      items.first(5)
    end

    def history_text_section
      items = history_items
      return nil if items.blank?

      lines = ["【ご確認いただいた内容】"]
      items.each { |item| lines << "・#{item[:value]}" }
      lines.join("\n")
    end

    def history_html_section
      items = history_items
      return "" if items.blank?

      bullets = items.map do |item|
        %(<p style="margin:0 0 6px;font-size:14px;line-height:1.6;color:#0f172a;">・#{h(item[:value])}</p>)
      end.join

      <<~HTML
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:8px 0 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;">
          <tr>
            <td style="padding:16px 18px;">
              <p style="margin:0 0 10px;font-size:13px;font-weight:700;letter-spacing:0.04em;color:#0f172a;">ご確認いただいた内容</p>
              #{bullets}
            </td>
          </tr>
        </table>
      HTML
    end

    def appeal_html
      %(<p style="margin:0 0 20px;padding:14px 16px;background:#0f172a;color:#ffffff;border-radius:10px;font-size:14px;line-height:1.7;">#{h(customer_offer)}。下のボタンからすぐ進められます。</p>)
    end

    def template
      @delivery.deal_follow_up_template
    end

    def sales_tracking_url
      Rails.application.routes.url_helpers.follow_up_click_url(
        @delivery.sales_click_token,
        host: default_host,
        protocol: default_protocol
      )
    end

    def contract_tracking_url
      Rails.application.routes.url_helpers.follow_up_click_url(
        @delivery.contract_click_token,
        host: default_host,
        protocol: default_protocol
      )
    end

    def unsubscribe_url
      Rails.application.routes.url_helpers.follow_up_unsubscribe_url(
        @user_progress.follow_up_unsubscribe_token,
        host: default_host,
        protocol: default_protocol
      )
    end

    def show_sales_call_link?
      template.nil? || template.include_sales_call_link?
    end

    def show_contract_link?
      template.nil? || template.include_contract_link?
    end

    def cta_text_section
      lines = []
      lines << "契約について相談する: #{contract_tracking_url}" if show_contract_link?
      lines << "担当者に相談する: #{sales_tracking_url}" if show_sales_call_link?
      lines.presence&.join("\n")
    end

    def cta_html_section
      return "" unless show_contract_link? || show_sales_call_link?

      left = if show_contract_link?
        button_cell(contract_tracking_url, "契約について相談する", "#0f172a", "#ffffff")
      else
        "<td></td>"
      end

      right = if show_sales_call_link?
        button_cell(sales_tracking_url, "担当者に相談する", "#ffffff", "#0f172a", border: true)
      else
        "<td></td>"
      end

      <<~HTML
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:8px 0 4px;">
          <tr>
            #{left}
            <td width="12" style="font-size:0;line-height:0;">&nbsp;</td>
            #{right}
          </tr>
        </table>
      HTML
    end

    def button_cell(url, label, background, color, border: false)
      border_css = border ? "border:2px solid #0f172a;" : "border:2px solid #{background};"
      <<~HTML
        <td width="50%" valign="top" style="width:50%;">
          <a href="#{url}" style="display:block;text-align:center;padding:14px 10px;background:#{background};color:#{color};text-decoration:none;border-radius:8px;font-weight:700;font-size:14px;line-height:1.3;#{border_css}">#{h(label)}</a>
        </td>
      HTML
    end
  end
end
