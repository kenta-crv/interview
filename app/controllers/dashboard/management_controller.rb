module Dashboard
  class ManagementController < ApplicationController
    layout "dashboard"

    before_action :authenticate_admin!

    def index
      @clients = Client.order(created_at: :desc)
      client_ids = @clients.map(&:id)

      @deal_counts = Deal.where(client_id: client_ids).group(:client_id).count
      @lead_counts = UserProgress.joins(:deal)
                                 .where(deals: { client_id: client_ids })
                                 .group("deals.client_id")
                                 .count
      @published_deal_counts = Deal.where(client_id: client_ids, playback_ready: true)
                                   .group(:client_id)
                                   .count
      @visitor_progresses = UserProgress.includes(:user, deal: :client).order(updated_at: :desc).limit(100)
      @journeys = UserProgress.journey_summaries_for(@visitor_progresses)
    end
  end
end
