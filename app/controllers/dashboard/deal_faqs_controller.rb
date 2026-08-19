class Dashboard::DealFaqsController < Dashboard::BaseController
  before_action :set_deal
  before_action :authorize_deal_management!
  before_action :set_faq, only: [:update, :destroy, :skip]

  def create
    @faq = @deal.deal_faqs.build(deal_faq_params.merge(source: "manual", status: "approved"))
    @faq.position = @deal.deal_faqs.maximum(:position).to_i + 1

    if @faq.save
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: t("meetia.dashboard.flash.faq_added")
    else
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: @faq.errors.full_messages.join(", ")
    end
  end

  def update
    attrs = deal_faq_params
    attrs[:status] = "approved" if attrs[:answer].present? && @faq.pending?

    if @faq.update(attrs)
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: t("meetia.dashboard.flash.faq_updated")
    else
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: @faq.errors.full_messages.join(", ")
    end
  end

  def destroy
    @faq.destroy!
    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: t("meetia.dashboard.flash.faq_deleted")
  end

  def skip
    @faq = @deal.deal_faqs.find(params[:id])
    @faq.skip!
    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: t("meetia.dashboard.flash.faq_skipped")
  end

  def analyze_gaps
    if @deal.deal_summary.blank?
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: t("meetia.dashboard.flash.gap_need_summary")
      return
    end

    result = DealEngine::FaqGapAnalysisService.new(@deal, client: current_client).analyze!
    notice = if result[:created].to_i.positive?
      t("meetia.dashboard.flash.gap_suggested", count: result[:created])
    else
      t("meetia.dashboard.flash.gap_none")
    end

    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: notice
  end

  def suggest_from_events
    limit = current_client.on_trial? ? 3 : 10
    result = DealEngine::FaqFromEventsService.new(@deal, limit: limit).suggest!
    notice = if result[:created].to_i.positive?
      t("meetia.dashboard.flash.events_suggested", count: result[:created])
    else
      t("meetia.dashboard.flash.events_none")
    end

    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: notice
  end

  def stress_test
    if @deal.deal_summary.blank?
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: t("meetia.dashboard.flash.stress_need_summary")
      return
    end

    result = DealEngine::BuyerStressTestService.new(@deal, client: current_client).run!
    notice = if result[:created].to_i.positive?
      t("meetia.dashboard.flash.stress_added", tested: result[:tested], created: result[:created])
    else
      t("meetia.dashboard.flash.stress_ok")
    end

    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: notice
  end

  private

  def set_deal
    @deal = if acting_as_admin?
              Deal.find(params[:deal_id])
            else
              current_client.deals.where(managed_by_admin: false).find(params[:deal_id])
            end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_deals_path, alert: t("meetia.dashboard.flash.deal_not_found")
  end

  def set_faq
    @faq = @deal.deal_faqs.find(params[:id])
  end

  def deal_faq_params
    params.require(:deal_faq).permit(:question, :answer, :category, :status)
  end
end
