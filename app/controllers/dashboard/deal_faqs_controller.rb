class Dashboard::DealFaqsController < Dashboard::BaseController
  before_action :set_deal
  before_action :set_faq, only: [:update, :destroy]

  def create
    @faq = @deal.deal_faqs.build(deal_faq_params.merge(source: "manual", status: "approved"))
    @faq.position = @deal.deal_faqs.maximum(:position).to_i + 1

    if @faq.save
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: "FAQを追加しました"
    else
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: @faq.errors.full_messages.join(", ")
    end
  end

  def update
    attrs = deal_faq_params
    attrs[:status] = "approved" if attrs[:answer].present? && @faq.pending?

    if @faq.update(attrs)
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: "FAQを更新しました"
    else
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: @faq.errors.full_messages.join(", ")
    end
  end

  def destroy
    @faq.destroy!
    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: "FAQを削除しました"
  end

  def skip
    @faq = @deal.deal_faqs.find(params[:id])
    @faq.skip!
    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: "提案をスキップしました"
  end

  def analyze_gaps
    if @deal.deal_summary.blank?
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: "資料処理が完了してからギャップ分析を実行できます"
      return
    end

    result = DealEngine::FaqGapAnalysisService.new(@deal, client: current_client).analyze!
    notice = if result[:created].to_i.positive?
      "資料をもとにBuyerが聞きそうな質問を#{result[:created]}件提案しました"
    else
      "新しい提案はありません（既存FAQでカバー済みの可能性があります）"
    end

    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: notice
  end

  def suggest_from_events
    limit = current_client.on_trial? ? 3 : 10
    result = DealEngine::FaqFromEventsService.new(@deal, limit: limit).suggest!
    notice = if result[:created].to_i.positive?
      "商談ログから#{result[:created]}件のFAQ候補を追加しました"
    else
      "新しいFAQ候補はありません"
    end

    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: notice
  end

  def stress_test
    if @deal.deal_summary.blank?
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: "資料処理が完了してからストレステストを実行できます"
      return
    end

    result = DealEngine::BuyerStressTestService.new(@deal, client: current_client).run!
    notice = if result[:created].to_i.positive?
      "厳しいBuyer質問#{result[:tested]}件中、未カバー#{result[:created]}件をFAQ候補に追加しました"
    else
      "ストレステスト完了：主要な質問はFAQでカバーされています"
    end

    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), notice: notice
  end

  private

  def set_deal
    @deal = current_client.deals.find(params[:deal_id])
  end

  def set_faq
    @faq = @deal.deal_faqs.find(params[:id])
  end

  def deal_faq_params
    params.require(:deal_faq).permit(:question, :answer, :category, :status)
  end
end
