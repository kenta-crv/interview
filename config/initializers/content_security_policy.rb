# Tag Assistant が meetia.pro を埋め込んで接続できるよう frame-ancestors を許可する。
# X-Frame-Options: SAMEORIGIN だと Tag Assistant 接続がタイムアウトするため外し、
# CSP frame-ancestors で 'self' + Google Tag Assistant 系のみ許可する。
Rails.application.config.content_security_policy do |policy|
  policy.frame_ancestors :self,
                         "https://tagassistant.google.com",
                         "https://www.googletagmanager.com",
                         "https://ads.google.com",
                         "https://*.google.com"
end

Rails.application.config.action_dispatch.default_headers.delete("X-Frame-Options")
