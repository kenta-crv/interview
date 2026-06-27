# app/controllers/api/ai_responses_controller.rb
class Api::AiResponsesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_deal

  def create
    service = DealEngine::ConversationService.new(@deal)
    result = service.respond(
      topic: params[:topic],
      message: params[:message],
      page_number: params[:page_number]
    )

    render json: {
      response: result[:text],
      type: result[:type],
      audio_url: result[:audio_url],
      page_number: result[:page_number],
      page_title: result[:page_title],
      follow_up: result[:follow_up]
    }
  rescue => e
    Rails.logger.error("AI response error: #{e.message}")
    render json: { response: fallback_response(params[:topic] || params[:message]) }, status: :ok
  end

  private

  def set_deal
    @deal = Deal.find(params[:deal_id])
  end

  def fallback_response(topic)
    DealEngine::ConversationService.new(@deal).send(:fallback_response, topic)
  end
end
