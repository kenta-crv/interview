# app/controllers/public/deal_sessions_controller.rb
module Public
  class DealSessionsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_deal_by_token

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

        # セッションにユーザーを設定
        session[:user_id] = @user.id

        redirect_to conversation_public_deal_session_path(token: @deal.access_token), notice: '情報を登録しました'
      else
        render :show, status: :unprocessable_entity
      end
    end

    def conversation
      @user = User.find_by(id: session[:user_id])
      unless @user
        redirect_to public_deal_session_path(token: @deal.access_token), alert: 'まず情報を登録してください'
        return
      end

      @user_progress = @deal.user_progresses.find_by(user: @user)
      unless @user_progress
        redirect_to public_deal_session_path(token: @deal.access_token), alert: 'まず情報を登録してください'
        return
      end

      @conversation_messages = initialize_conversation
      @documents = @deal.deal_documents
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

    def user_params
      params.require(:user).permit(:name, :company, :tel, :address, :email, :url)
    end

    def initialize_conversation
      [
        { role: 'assistant', content: greeting_message },
        { role: 'assistant', content: company_introduction },
        { role: 'assistant', content: usage_guide }
      ]
    end

    def greeting_message
      if @deal.language == 'ja'
        "こんにちは！#{@deal.client.email}のAI商談アシスタントです。本日はお時間をいただきありがとうございます。"
      else
        "Hello! I'm the AI sales assistant from #{@deal.client.email}. Thank you for your time today."
      end
    end

    def company_introduction
      if @deal.language == 'ja'
        "私たちは#{@deal.client.email}で、AIを活用した商談支援サービスを提供しています。"
      else
        "We at #{@deal.client.email} provide AI-powered sales support services."
      end
    end

    def usage_guide
      if @deal.language == 'ja'
        "このAI商談では、以下のトピックについてお話しできます：\n・サービス概要\n・料金プラン\n・トライアルについて\n・契約フロー\n\n知りたいトピックを選んでください。"
      else
        "In this AI sales conversation, we can discuss:\n・Service Overview\n・Pricing Plans\n・Trial Information\n・Contract Flow\n\nPlease select a topic you'd like to know about."
      end
    end
  end
end
