# app/controllers/public/deal_sessions_controller.rb
module Public
  class DealSessionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:respond, :evaluate, :track_event]
    before_action :set_deal_by_token
    before_action :require_registered_user, only: [:conversation, :playback, :respond, :evaluate]
    before_action :load_tracking_context, only: [:track_event]

    def show
      @user_progress = @deal.user_progresses.find_or_initialize_by(user: current_user)
    end

    def create_user_info
      @user = User.find_or_initialize_by(email: user_params[:email])
      @user.assign_attributes(user_params.except(:email))
      @user.password = SecureRandom.hex(16) if @user.new_record?

      if @user.save
        @user_progress = @deal.user_progresses.find_or_initialize_by(user: @user)
        @user_progress.update!(
          consideration_phase: params[:consideration_phase],
          planned_introduction_date: params[:planned_introduction_date],
          key_points_for_application: params[:key_points_for_application]
        )

        session[:user_id] = @user.id
        redirect_to conversation_public_deal_session_path(token: @deal.access_token), notice: '情報を登録しました'
      else
        render :show, status: :unprocessable_entity
      end
    end

    def conversation
      load_deal_experience_data
    end

    def playback
      render json: @deal.playback_payload
    end

    def respond
      topic = params[:topic]
      message = params[:message]
      page_number = params[:page_number]
      history = conversation_history_param

      if page_number.blank? && topic.present?
        menu_item = @deal.presentation_menu_items.find { |item| item['key'] == topic.to_s }
        page_number = menu_item&.dig('page_number')
      end

      service = DealEngine::ConversationService.new(@deal, user_progress: @user_progress)
      result = service.respond(
        topic: topic,
        message: message,
        page_number: page_number,
        history: history
      )

      log_ai_reply!(result, message: message, page_number: page_number)

      render json: result
    end

    def evaluate
      rating = params[:rating].to_i
      unless (1..5).cover?(rating)
        render json: { errors: ['評価は1〜5で指定してください'] }, status: :unprocessable_entity
        return
      end

      evaluation = @deal.deal_evaluations.find_or_initialize_by(user: @user)
      evaluation.update!(rating: rating, feedback: params[:feedback])

      render json: { message: '評価を保存しました' }
    end

    def track_event
      data = json_request_params
      session_key = data['session_key']
      events = normalize_track_events(data)
      return head :bad_request if session_key.blank? || events.blank?

      events.each do |event|
        event_type = event[:event_type].to_s
        next unless DealPresentationEvent::EVENT_TYPES.include?(event_type)

        metadata = (event[:metadata] || {}).merge(client_preview? ? { preview: true } : {})

        @deal.deal_presentation_events.create!(
          user: @user,
          user_progress: @user_progress,
          session_key: session_key,
          event_type: event_type,
          page_number: event[:page_number],
          topic: event[:topic],
          label: event[:label],
          message: event[:message],
          metadata: metadata,
          occurred_at: parse_event_time(event[:occurred_at])
        )
      end

      head :ok
    end

    private

    def json_request_params
      if params[:session_key].present? || params[:event_type].present?
        return params.to_unsafe_h
      end

      return {} unless request.content_type.to_s.include?('application/json')

      body = request.body.read
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end

    def normalize_track_events(data)
      data = data.to_unsafe_h if data.respond_to?(:to_unsafe_h)
      data = data.with_indifferent_access

      if data[:events].present?
        Array(data[:events]).map { |event| event.to_h.symbolize_keys }
      elsif data[:event_type].present?
        [data.slice(:event_type, :page_number, :topic, :label, :message, :occurred_at, :metadata).symbolize_keys]
      else
        []
      end
    end

    def parse_event_time(value)
      return Time.current if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      Time.current
    end

    def load_deal_experience_data
      @deal_pages = @deal.deal_pages.order(:page_number)
      @menu_items = @deal.presentation_menu_items
      @opening_payload = @deal.presentation_opening_payload
      @opening_segments = @deal.presentation_opening_segments
      @conversation_messages = @deal.conversation_opening_messages
    end

    def set_deal_by_token
      @deal = Deal.by_token(params[:token]).first
      unless @deal
        redirect_to root_path, alert: '無効なリンクです'
        return
      end
    rescue StandardError
      redirect_to root_path, alert: '無効なリンクです'
    end

    def require_registered_user
      return if client_preview?

      @user = User.find_by(id: session[:user_id])
      unless @user
        redirect_to public_deal_session_path(token: @deal.access_token), alert: 'まず情報を登録してください'
        return
      end

      @user_progress = @deal.user_progresses.find_by(user: @user)
      unless @user_progress
        redirect_to public_deal_session_path(token: @deal.access_token), alert: 'まず情報を登録してください'
      end
    end

    def load_tracking_context
      return if client_preview?

      @user = User.find_by(id: session[:user_id])
      @user_progress = @deal.user_progresses.find_by(user: @user) if @user
      head :forbidden unless @user_progress
    end

    def client_preview?
      return false unless params[:preview].present?

      if admin_signed_in?
        return true
      end

      client_signed_in? && @deal.client_id == current_client.id
    end

    def user_params
      params.require(:user).permit(:name, :job_title, :company, :tel, :address, :email, :url)
    end

    def log_ai_reply!(result, message:, page_number:)
      return if client_preview?
      return unless @user_progress
      return unless result.is_a?(Hash) && result[:type].to_s == 'ai'
      return if result[:text].blank?

      session_key = params[:session_key].presence
      return if session_key.blank?

      @deal.deal_presentation_events.create!(
        user: @user,
        user_progress: @user_progress,
        session_key: session_key,
        event_type: 'ai_reply',
        page_number: page_number,
        message: result[:text].to_s.truncate(2000),
        metadata: { user_message: message.to_s.truncate(500) },
        occurred_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to log ai_reply: #{e.message}")
    end

    def conversation_history_param
      raw = params[:history]
      return [] if raw.blank?

      list = if raw.is_a?(Array)
               raw
             elsif raw.respond_to?(:values)
               raw.values
             else
               Array(raw)
             end

      list.map do |item|
        if item.respond_to?(:to_unsafe_h)
          item.to_unsafe_h
        elsif item.respond_to?(:to_h)
          item.to_h
        else
          item
        end
      end
    end
  end
end
