module DealFollowUp
  class EnqueueCampaignService
    def self.call(user_progress:, ended_at: Time.current)
      new(user_progress: user_progress, ended_at: ended_at).call
    end

    def initialize(user_progress:, ended_at:)
      @user_progress = user_progress
      @ended_at = ended_at
    end

    def call
      return unless eligible?

      ActiveRecord::Base.transaction do
        lock_progress!
        return if already_enqueued?

        @user_progress.update!(session_ended_at: @ended_at)
        @user_progress.ensure_follow_up_unsubscribe_token!

        enabled_templates.each do |template|
          create_and_schedule_delivery!(template)
        end
      end
    end

    private

    def eligible?
      client.prospect_follow_up_enabled? &&
        @user_progress.user&.email.present? &&
        !@user_progress.follow_up_unsubscribed?
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
      delivery = @user_progress.follow_up_deliveries.create!(
        deal_follow_up_template: template,
        sequence: template.sequence,
        subject: template.subject,
        body: template.body,
        scheduled_at: scheduled_at,
        status: "scheduled"
      )

      if scheduled_at <= Time.current
        DealFollowUp::SendDeliveryJob.perform_later(delivery.id)
      else
        DealFollowUp::SendDeliveryJob.set(wait_until: scheduled_at).perform_later(delivery.id)
      end
    end
  end
end
