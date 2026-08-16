class UnsubscribesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    customer = Customer.find_by(
      unsubscribe_token: params[:token]
    )

    if customer.blank?
      render plain: t("meetia.common.invalid_url"), status: :not_found
      return
    end

    customer.update!(
      fobbiden: 't'
    )

    render inline: <<~HTML
      <!DOCTYPE html>
      <html lang="#{I18n.locale}">
      <head>
        <meta charset="UTF-8">
        <title>#{ERB::Util.html_escape(t("meetia.unsubscribe.done_title"))}</title>

        <style>
          body {
            font-family: sans-serif;
            background: #f5f7fb;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
          }

          .box {
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.08);
            text-align: center;
          }

          h1 {
            margin-bottom: 12px;
          }

          p {
            color: #666;
          }
        </style>
      </head>

      <body>
        <div class="box">
          <h1>#{ERB::Util.html_escape(t("meetia.unsubscribe.done_heading"))}</h1>
          <p>#{ERB::Util.html_escape(t("meetia.unsubscribe.done_body"))}</p>
        </div>
      </body>
      </html>
    HTML
  end
end