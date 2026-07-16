class Dashboard::DealsController < Dashboard::BaseController
  include FileUploadValidation

  before_action :authenticate_client_only!, except: [:index, :show, :presentation]
  before_action :set_deal, only: [:show, :edit, :update, :destroy, :presentation, :update_content, :ai_rewrite, :regenerate_audio, :publish, :reprocess, :reset_processing, :upload_documents, :upload_supplement_documents, :update_presentation_settings, :update_follow_up_settings, :processing_status]
  before_action :load_deal_associations, only: [:show]
  before_action :ensure_deal_quota!, only: [:new, :create]

  def index
    @deals = if admin_signed_in?
               Deal.includes(:deal_documents, :deal_audios, :deal_transcript, :deal_summary, :deal_speeches).order(created_at: :desc)
             else
               current_client.deals.includes(:deal_documents, :deal_audios, :deal_transcript, :deal_summary, :deal_speeches).order(created_at: :desc)
             end
  end

  def show
    owner = deal_owner
    @deal_audio = @deal.deal_audios.first
    @segments = @deal_audio&.deal_segments&.in_order || []
    @situations = owner.situations.active
    @deal_pages = @deal.deal_pages.order(:page_number)
    @deal_faqs = @deal.deal_faqs.ordered
    @knowledge_coverage = @deal.knowledge_coverage_percent
    @pending_faq_count = @deal.pending_faq_count
    @supplement_documents = @deal.deal_documents.supplements
    @presentation_events = if owner.click_analytics_enabled?
      @deal.deal_presentation_events.includes(:user).recent_first.limit(100)
    else
      []
    end
    @deal_evaluations = @deal.deal_evaluations.includes(:user).order(created_at: :desc).limit(50)
    @analytics = DealEngine::AnalyticsSummaryService.call(deal_ids: [@deal.id])
    @evaluation_count = @analytics[:evaluation_count]
    @average_evaluation = @analytics[:average_evaluation]
    @prospect_grade_counts = @analytics[:prospect_grade_counts]
    if owner.prospect_follow_up_enabled?
      @deal.ensure_follow_up_templates!
      @follow_up_templates = @deal.deal_follow_up_templates.ordered
    end
  end

  def presentation
    unless client_signed_in? || admin_signed_in?
      redirect_to new_client_session_path, alert: "ログインが必要です。"
      return
    end

    redirect_to conversation_public_deal_session_path(token: @deal.access_token, preview: 1),
                notice: "即時プレゼン画面を開きます"
  end

  def update_content
    @deal.update!(deal_content_params) if params[:deal].present?

    if params[:pages].present?
      params[:pages].each do |page_id, page_params|
        page = @deal.deal_pages.find_by(id: page_id)
        next unless page

        page.update!(page_params.permit(:title, :script))
      end
    end

    redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), notice: '商談コンテンツを更新しました'
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: e.message
  end

  def ai_rewrite
    target = params[:target]
    instruction = params[:instruction]
    Rails.logger.info("ai_rewrite start deal=#{@deal.id} target=#{target} page_id=#{params[:page_id]}")
    generator = DealEngine::ScriptGeneratorService.new(@deal)

    case target
    when 'greeting', 'company_overview', 'usage_guide'
      field = "#{target}_script"
      original = @deal.public_send(field).presence || @deal.public_send("default_#{target}_text")
      rewritten = generator.rewrite_script(original, instruction: instruction)
      @deal.update!(field => rewritten)
      DealEngine::AudioGeneratorService.new(@deal).generate_opening_audios!
    when 'page'
      page = @deal.deal_pages.find_by(id: params[:page_id])
      unless page
        redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: 'ページが見つかりません'
        return
      end
      original = page.script.presence || page.page_text.presence
      if original.blank?
        redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: '台本が空のためAI改善できません。先に台本を入力するか、PDFを再処理してください。'
        return
      end
      rewritten = generator.rewrite_script(original, instruction: instruction)
      page.update!(script: rewritten)
      DealEngine::AudioGeneratorService.new(@deal).generate_for_page!(page)
    when 'menu'
      generator.generate_menu_items!
    else
      redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: '不明な対象です'
      return
    end

    redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), notice: 'AIで書き直しました'
  rescue => e
    Rails.logger.error("ai_rewrite failed: #{e.message}")
    redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: "AI改善に失敗しました: #{e.message}"
  end

  def regenerate_audio
    if params[:tts_voice_gender].present?
      gender = params[:tts_voice_gender].to_s
      unless Deal::TTS_VOICE_GENDERS.key?(gender)
        redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: '声の設定が不正です'
        return
      end
      @deal.update!(tts_voice_gender: gender)
    end

    voice_label = Deal::TTS_VOICE_GENDERS[@deal.tts_voice_gender] || '選択した声'

    if params[:page_id].present?
      page = @deal.deal_pages.find(params[:page_id])
      DealEngine::AudioGeneratorService.new(@deal).generate_for_page!(page)
      redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'),
                  notice: "このページを#{voice_label}の声で作り直しました"
    else
      # Sidekiqに頼ると完了前に画面へ戻り、古い音声のまま聞こえるため同期実行する
      DealEngine::AudioGeneratorService.new(@deal).generate_all!
      @deal.touch
      redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'),
                  notice: "#{voice_label}の声で読み上げを作り直しました。下のプレイヤーで確認できます。"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: e.message
  rescue => e
    Rails.logger.error("regenerate_audio failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}")
    redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: "読み上げの作成に失敗しました: #{e.message}"
  end

  def processing_status
    render json: {
      status: @deal.status,
      pages_count: @deal.deal_pages.count,
      playback_ready: @deal.playback_ready,
      failed: @deal.failed?,
      processing: @deal.processing?
    }
  end

  def reprocess
    if @deal.deal_documents.empty?
      redirect_to dashboard_deal_path(@deal), alert: '資料がありません。先にPDFをアップロードしてください'
      return
    end

    if @deal.processing?
      redirect_to dashboard_deal_path(@deal), alert: 'AI処理中です。完了までお待ちください'
      return
    end

    @deal.start_processing!
    ProcessDealJob.perform_later(@deal.id)
    redirect_to dashboard_deal_path(@deal), notice: 'AI処理を開始しました。完了まで数分かかる場合があります'
  end

  def reset_processing
    unless @deal.processing?
      redirect_to dashboard_deal_path(@deal), alert: '処理中ではありません'
      return
    end

    @deal.fail!
    redirect_to dashboard_deal_path(@deal), notice: '処理状態をリセットしました。再度アップロードできます。'
  end

  def update_presentation_settings
    @deal.update!(presentation_settings_params)
    redirect_to dashboard_deal_path(@deal, anchor: 'presentation-cta'), notice: 'プレゼンCTA設定を更新しました'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_deal_path(@deal, anchor: 'presentation-cta'), alert: e.message
  end

  def update_follow_up_settings
    unless current_client.prospect_follow_up_enabled?
      redirect_to dashboard_deal_path(@deal), alert: '現在のプランではフォローアップ機能を利用できません'
      return
    end

    ActiveRecord::Base.transaction do
      @deal.update!(follow_up_settings_params) if params[:deal].present?

      Array(params[:templates]).each do |template_id, template_params|
        template = @deal.deal_follow_up_templates.find(template_id)
        template.update!(follow_up_template_params(template_params))
      end
    end

    redirect_to dashboard_deal_path(@deal, anchor: 'follow-up-settings'), notice: 'フォローアップ設定を更新しました'
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to dashboard_deal_path(@deal, anchor: 'follow-up-settings'), alert: e.message
  end

  def upload_documents
    if params[:files].blank?
      redirect_to dashboard_deal_path(@deal), alert: 'ファイルが選択されていません'
      return
    end

    if @deal.processing?
      redirect_to dashboard_deal_path(@deal), alert: 'AI処理中です。完了までお待ちください'
      return
    end

    ActiveRecord::Base.transaction do
      params[:files].each do |file|
        document = @deal.deal_documents.create!(
          filename: file.original_filename,
          content_type: file.content_type,
          file_size: file.size,
          document_kind: "proposal"
        )
        document.file.attach(file)
      end
    end

    @deal.start_processing!
    ProcessDealJob.perform_later(@deal.id)

    redirect_to dashboard_deal_path(@deal), notice: '資料をアップロードしました。AI処理をバックグラウンドで開始しています'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_deal_path(@deal), alert: e.message
  rescue ActiveRecord::StatementInvalid => e
    if e.cause.is_a?(SQLite3::BusyException)
      redirect_to dashboard_deal_path(@deal), alert: 'データベースが混雑しています。数秒待ってから再度お試しください'
    else
      redirect_to dashboard_deal_path(@deal), alert: "エラーが発生しました: #{e.message}"
    end
  rescue StandardError => e
    redirect_to dashboard_deal_path(@deal), alert: "エラーが発生しました: #{e.message}"
  end

  def upload_supplement_documents
    if params[:files].blank?
      redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: "ファイルが選択されていません"
      return
    end

    created_docs = []

    ActiveRecord::Base.transaction do
      params[:files].each do |file|
        document = @deal.deal_documents.create!(
          filename: file.original_filename,
          content_type: file.content_type,
          file_size: file.size,
          document_kind: "supplement"
        )
        document.file.attach(file)
        created_docs << document
      end
    end

    created_docs.each { |doc| ExtractSupplementFaqsJob.perform_later(doc.id) }

    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"),
                notice: "補足資料をアップロードしました。FAQ抽出をバックグラウンドで実行しています"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_deal_path(@deal, anchor: "deal-knowledge"), alert: e.message
  end

  def publish
    if @deal.deal_pages.empty?
      redirect_to dashboard_deal_path(@deal, anchor: 'content-edit'), alert: 'スライドが未生成です。先にPDFをアップロードしてください'
      return
    end

    @deal.update!(playback_ready: true, status: :completed)
    redirect_to dashboard_deal_path(@deal), notice: '商談URLを公開しました'
  end

  def new
    @deal = current_client.deals.build
  end

  def create
    @deal = current_client.deals.build(deal_params)

    if @deal.save
      redirect_to dashboard_deal_path(@deal), notice: '商談を作成しました'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @deal.update(deal_params)
      redirect_to dashboard_deal_path(@deal), notice: '商談を更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @deal.destroy
    redirect_to dashboard_deals_path, notice: '商談を削除しました'
  end

  private

  def set_deal
    @deal = if admin_signed_in?
              Deal.find(params[:id])
            else
              current_client.deals.find(params[:id])
            end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_deals_path, alert: "商談が見つかりません。"
  end

  def load_deal_associations
    @deal = Deal.includes(:deal_summary, :deal_speeches, :deal_pages, :deal_faqs).find(@deal.id)
  end

  def deal_params
    params.require(:deal).permit(:title, :description, :deal_date, :language, :tts_voice_gender)
  end

  def deal_content_params
    params.require(:deal).permit(:greeting_script, :company_overview_script, :usage_guide_script)
  end

  def presentation_settings_params
    params.require(:deal).permit(
      :presentation_cta_label,
      :presentation_cta_url,
      :exit_contract_label,
      :exit_sales_call_label
    )
  end

  def follow_up_settings_params
    params.require(:deal).permit(:follow_up_sales_url)
  end

  def follow_up_template_params(raw_params)
    permitted = raw_params.permit(:enabled, :delay_days, :subject, :body, :include_sales_call_link, :include_contract_link)
    {
      enabled: ActiveModel::Type::Boolean.new.cast(permitted[:enabled]),
      delay_days: permitted[:delay_days],
      subject: permitted[:subject],
      body: permitted[:body],
      include_sales_call_link: ActiveModel::Type::Boolean.new.cast(permitted[:include_sales_call_link]),
      include_contract_link: ActiveModel::Type::Boolean.new.cast(permitted[:include_contract_link])
    }
  end

  def ensure_deal_quota!
    return if current_client.can_create_deal?

    redirect_to dashboard_deals_path, alert: current_client.deal_limit_message
  end
end
