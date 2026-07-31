module DealFollowUp
  class EnqueueCampaignService
    def self.call(user_progress:, ended_at: Time.current, force: false)
      new(user_progress: user_progress, ended_at: ended_at, force: force).call
    end

    def initialize(user_progress:, ended_at:, force: false)
      @user_progress = user_progress
      @ended_at = ended_at
      @force = force
    end

    def call
      return unless eligible?

      ActiveRecord::Base.transaction do
        lock_progress!
        unless already_enqueued?
          @user_progress.update!(session_ended_at: @ended_at)
          @user_progress.ensure_follow_up_unsubscribe_token!

          enabled_templates.each do |template|
            create_and_schedule_delivery!(template)
          end
        end
      end

      # 既存キャンペーンでも未送信の即時分は必ず同期送信する
      # （return if already_enqueued? で送信まで飛ばないようにする）
      send_immediate_deliveries!
    end

    private

    def eligible?
      follow_up_allowed? &&
        @user_progress.user&.email.present? &&
        !@user_progress.follow_up_unsubscribed?
    end

    def follow_up_allowed?
      @force || @user_progress.deal.managed_by_admin? || client&.prospect_follow_up_enabled?
    end

    def client
      @user_progress.deal.client
    end

    def lock_progress!
      @user_progress = UserProgress.lock.find(@user_progress.id)
    end

    def already_enqueued?
      @user_progress.follow_up_deliveries.exists?
    end

    def enabled_templates
      @user_progress.deal.deal_follow_up_templates.enabled.ordered
    end

    def create_and_schedule_delivery!(template)
      scheduled_at = @ended_at + template.delay_days.days
      @user_progress.follow_up_deliveries.create!(
        deal_follow_up_template: template,
        sequence: template.sequence,
        subject: template.subject,
        body: template.body,
        scheduled_at: scheduled_at,
        status: "scheduled"
      )
    end

    def send_immediate_deliveries!
      # 即時分のみ。翌日以降は system cron（rake deal_follow_up:send_due）
      # failed も再送対象（SMTP障害後のリトライ用）
      @user_progress.follow_up_deliveries
        .where(status: %w[scheduled failed])
        .where("scheduled_at <= ?", Time.current)
        .includes(:deal_follow_up_template)
        .find_each do |delivery|
          next if delivery.deal_follow_up_template.delay_days.to_i.positive?

          SendDeliveryService.call(delivery)
        rescue StandardError => e
          Rails.logger.error(
            "[DealFollowUp] immediate send failed delivery_id=#{delivery.id}: #{e.class}: #{e.message}"
          )
        end
    end
  end
end
