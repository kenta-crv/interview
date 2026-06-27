# app/controllers/public/deal_sessions_controller.rb
module Public
  class DealSessionsController < ApplicationController
    layout 'deal_public'
    skip_before_action :verify_authenticity_token, only: [:respond, :evaluate]
    before_action :set_deal_by_token
    before_action :require_registered_user, only: [:conversation, :playback, :respond, :evaluate]

    def show
      @user_progress = @deal.user_progresses.find_or_initialize_by(user: current_user)
    end

    def create_user_info
      @user = User.find_or_initialize_by(email: user_params[:email])

      if @user.new_record?
        @user.assign_attributes(user_params.except(:email))
        @user.password = SecureRandom.hex(16)
      end

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
      @menu_items = @deal.menu_items_for_conversation
      @conversation_messages = @deal.conversation_opening_messages
    end

    def playback
      render json: @deal.playback_payload
    end

    def respond
      topic = params[:topic]
      message = params[:message]
      page_number = params[:page_number]

      if page_number.blank? && topic.present?
        menu_item = @deal.menu_items_for_conversation.find { |item| item['key'] == topic.to_s }
        page_number = menu_item&.dig('page_number')
      end

      service = DealEngine::ConversationService.new(@deal, user_progress: @user_progress)
      result = service.respond(
        topic: topic,
        message: message,
        page_number: page_number
      )

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

    private

    def set_deal_by_token
      @deal = Deal.by_token(params[:token]).first
      unless @deal
        redirect_to root_path, alert: '無効なリンクです'
        return
      end
    rescue => e
      redirect_to root_path, alert: '無効なリンクです'
    end

    def require_registered_user
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

    def user_params
      params.require(:user).permit(:name, :company, :tel, :address, :email, :url)
    end
  end
end
