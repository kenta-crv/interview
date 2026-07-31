namespace :deal_follow_up do
  desc "Send follow-up emails whose scheduled_at has arrived"
  task send_due: :environment do
    DealFollowUp::SendDueDeliveriesService.call
  end

  desc "Test SMTP auth with a one-off mail (USAGE: rake deal_follow_up:test_smtp[to@example.com])"
  task :test_smtp, [:to] => :environment do |_t, args|
    to = args[:to].presence || Admin.order(:id).pick(:email)
    abort "to address required" if to.blank?

    settings = ActionMailer::Base.smtp_settings
    puts "SMTP address=#{settings[:address]} user=#{settings[:user_name]} pass=#{settings[:password].present? ? 'set' : 'MISSING'}"

    ActionMailer::Base.mail(
      to: to,
      from: "info@okey.work",
      subject: "【Meetia】SMTP test #{Time.current}",
      body: "SMTP authentication OK at #{Time.current}"
    ).deliver_now
    puts "OK: delivered to #{to}"
  rescue StandardError => e
    warn "FAIL: #{e.class}: #{e.message}"
    exit 1
  end
end
