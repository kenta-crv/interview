# app/controllers/api/deals_controller.rb
module Api
  class DealsController < ApplicationController
    include FileUploadValidation
    skip_before_action :verify_authenticity_token 
    before_action :authenticate_client!
    before_action :set_deal, only: [:show, :update, :process_pdf]

    # POST /api/deals
    def create
      @deal = current_client.deals.build(deal_params)

      if @deal.save
        render json: { deal: deal_json(@deal) }, status: :created
      else
        render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # GET /api/deals/:id
    def show
      render json: { deal: deal_json(@deal) }
    end

    # POST /api/deals/:id/upload_documents
    def upload_documents
      @deal = current_client.deals.find(params[:id])

      if params[:files].blank?
        redirect_to client_deal_path(@deal), alert: 'ファイルが選択されていません'
        return
      end

      documents = []

      # ログのトランザクション開始位置（37行目）に合わせて、全体を明示的に保護
      ActiveRecord::Base.transaction do
        params[:files].each do |file|
          document = @deal.deal_documents.create!(
            filename: file.original_filename,
            content_type: file.content_type,
            file_size: file.size
          )
          document.file.attach(file)
          documents << document
        end
      end

      # :inlineモードでの同期実行。ジョブ内部での例外でアップロード処理全体が
      # クラッシュするのを防ぐため、明示的に例外を捕捉してログに記録します。
      begin
        ProcessDealJob.perform_now(@deal.id)
      rescue => e
        logger.error "=== [ProcessDealJob Error in Inline Mode] ==="
        logger.error "Message: #{e.message}"
        logger.error e.backtrace.join("\n")
        # ジョブ内でfail!が呼ばれずに落ちた場合を考慮し、ステータスを確実にfailedに更新
        @deal.fail! if @deal.respond_to?(:fail!) && !@deal.failed?
      end

      redirect_to client_deal_path(@deal), notice: '資料をアップロードしました'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to client_deal_path(@deal), alert: e.message
    rescue => e
      redirect_to client_deal_path(@deal), alert: "エラーが発生しました: #{e.message}"
    end

    # POST /api/deals/:id/process_pdf
    def process_pdf
      @deal = current_client.deals.find(params[:id])

      if @deal.deal_documents.empty?
        render json: { errors: ['No documents found'] }, status: :bad_request
        return
      end

      begin
        # 既存のページを削除
        @deal.deal_pages.destroy_all

        # 各ドキュメントを処理
        @deal.deal_documents.each do |document|
          next unless document.content_type&.include?('pdf')

          processor = DealEngine::PdfProcessorService.new(document)
          processor.process!
        end

        render json: { message: 'PDF processing completed', pages_count: @deal.deal_pages.count }, status: :ok
      rescue => e
        logger.error "PDF processing failed: #{e.message}"
        render json: { errors: [e.message] }, status: :internal_server_error
      end
    end

    # POST /api/deals/:id/upload_audio
    def upload_audio
      @deal = current_client.deals.find(params[:id])

      if params[:audio].blank?
        redirect_to client_deal_path(@deal), alert: '音声ファイルが選択されていません'
        return
      end

      audio_file = params[:audio]

      # 音声ファイルのバリデーション
      validate_audio_upload!(audio_file)

      deal_audio = nil

      ActiveRecord::Base.transaction do
        deal_audio = @deal.deal_audios.create!(
          filename: audio_file.original_filename,
          content_type: audio_file.content_type,
          file_size: audio_file.size
        )
        deal_audio.audio_file.attach(audio_file)
      end

      # :inlineモードでの同期実行。同様にジョブのエラーを隔離します。
      begin
        ProcessDealJob.perform_now(@deal.id)
      rescue => e
        logger.error "=== [ProcessDealJob Error in Inline Mode] ==="
        logger.error "Message: #{e.message}"
        logger.error e.backtrace.join("\n")
        @deal.fail! if @deal.respond_to?(:fail!) && !@deal.failed?
      end

      redirect_to client_deal_path(@deal), notice: '音声ファイルをアップロードしました'
    rescue => e
      redirect_to client_deal_path(@deal), alert: "エラーが発生しました: #{e.message}"
    end

    # POST /api/deals/:id/generate_speech
    def generate_speech
      @deal = current_client.deals.find(params[:id])

      unless @deal.deal_summary.present?
        render json: { errors: ['No summary available for this deal'] }, status: :bad_request
        return
      end

      # 既存の音声がある場合はそれを返す
      existing_speech = @deal.deal_speeches.first
      if existing_speech && existing_speech.audio_file.attached?
        render json: { deal_speech: deal_speech_json(existing_speech) }, status: :ok
        return
      end

      # TTSで音声を生成
      begin
        audio_data = DealEngine::TTSService.generate_from_deal_summary(@deal)

        deal_speech = nil
        ActiveRecord::Base.transaction do
          deal_speech = @deal.deal_speeches.create!(
            filename: "speech_#{@deal.id}.mp3",
            content_type: 'audio/mpeg',
            file_size: audio_data.size,
            voice: 'alloy',
            language: @deal.language
          )
          deal_speech.audio_file.attach(
            io: StringIO.new(audio_data),
            filename: "speech_#{@deal.id}.mp3",
            content_type: 'audio/mpeg'
          )
        end

        render json: { deal_speech: deal_speech_json(deal_speech) }, status: :created
      rescue => e
        logger.error "TTS generation failed: #{e.message}"
        render json: { errors: [e.message] }, status: :internal_server_error
      end
    end

    # POST /api/deals/:id/start_presentation
    def start_presentation
      @deal = current_client.deals.find(params[:id])

      unless @deal.deal_summary.present?
        render json: { errors: ['No summary available for this deal'] }, status: :bad_request
        return
      end

      situation_id = params[:situation_id]
      unless situation_id
        render json: { errors: ['situation_id is required'] }, status: :bad_request
        return
      end

      situation = Situation.find(situation_id)

      # 既存のプレゼンテーションがある場合はそれを返す
      existing_presentation = @deal.deal_presentations.where(situation: situation).first
      if existing_presentation
        render json: { presentation: presentation_json(existing_presentation) }, status: :ok
        return
      end

      # 新しいプレゼンテーションを作成
      presentation = @deal.deal_presentations.create!(situation: situation)

      # ガイダンスを開始
      guidance_service = DealEngine::GuidanceService.new(presentation)
      guidance = guidance_service.start_presentation

      render json: { presentation: presentation_json(presentation), guidance: guidance }, status: :created
    rescue => e
      logger.error "Presentation start failed: #{e.message}"
      render json: { errors: [e.message] }, status: :internal_server_error
    end

    # POST /api/deals/:id/submit_choice
    def submit_choice
      @deal = current_client.deals.find(params[:id])

      presentation_id = params[:presentation_id]
      unless presentation_id
        render json: { errors: ['presentation_id is required'] }, status: :bad_request
        return
      end

      presentation = @deal.deal_presentations.find(presentation_id)
      choice = params[:choice]

      unless choice
        render json: { errors: ['choice is required'] }, status: :bad_request
        return
      end

      # ユーザーの選択を処理
      guidance_service = DealEngine::GuidanceService.new(presentation)
      guidance = guidance_service.handle_user_choice(choice)

      render json: { presentation: presentation_json(presentation), guidance: guidance }, status: :ok
    rescue => e
      logger.error "Choice submission failed: #{e.message}"
      render json: { errors: [e.message] }, status: :internal_server_error
    end

    # GET /api/deals
    def index
      @deals = current_client.deals.recent
      render json: { deals: @deals.map { |d| deal_json(d) } }
    end

    private

    def set_deal
      @deal = current_client.deals.find(params[:id])
    end

    def deal_params
      params.require(:deal).permit(:title, :description, :deal_date, :language)
    end

    def deal_json(deal)
      {
        id: deal.id,
        title: deal.title,
        description: deal.description,
        status: deal.status,
        language: deal.language,
        deal_date: deal.deal_date,
        created_at: deal.created_at,
        started_at: deal.started_at,
        completed_at: deal.completed_at,
        documents_count: deal.deal_documents.count,
        audio_count: deal.deal_audios.count,
        has_transcript: deal.deal_transcript.present?,
        has_summary: deal.deal_summary.present?
      }
    end

    def document_json(document)
      {
        id: document.id,
        filename: document.filename,
        content_type: document.content_type,
        file_size: document.file_size,
        created_at: document.created_at
      }
    end

    def deal_audio_json(deal_audio)
      {
        id: deal_audio.id,
        filename: deal_audio.filename,
        content_type: deal_audio.content_type,
        file_size: deal_audio.file_size,
        duration_seconds: deal_audio.duration_seconds,
        segment_count: deal_audio.segment_count,
        created_at: deal_audio.created_at
      }
    end

    def deal_speech_json(deal_speech)
      {
        id: deal_speech.id,
        filename: deal_speech.filename,
        content_type: deal_speech.content_type,
        file_size: deal_speech.file_size,
        voice: deal_speech.voice,
        language: deal_speech.language,
        audio_url: Rails.application.routes.url_helpers.rails_blob_path(deal_speech.audio_file, only_path: true),
        created_at: deal_speech.created_at
      }
    end

    def presentation_json(presentation)
      {
        id: presentation.id,
        deal_id: presentation.deal_id,
        situation_id: presentation.situation_id,
        status: presentation.status,
        current_step: presentation.current_step,
        user_choices: presentation.user_choices,
        latest_guidance: presentation.latest_guidance,
        created_at: presentation.created_at
      }
    end
  end
end