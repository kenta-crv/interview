# frozen_string_literal: true

# API共通のエラーハンドリング
# 統一的なJSONレスポンス形式でエラーを返却する
module ApiErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict
    rescue_from ActionController::BadRequest, with: :render_bad_request
  end

  private

  def render_api_error(message, status:, reason: nil, details: nil)
    body = { success: false, error: message }
    body[:reason] = reason if reason
    body[:details] = details if details
    render json: body, status: status
  end

  def render_not_found(exception)
    render_api_error(exception.message, status: :not_found)
  end

  def render_validation_error(exception)
    render_api_error(
      "Validation failed: #{exception.record.errors.full_messages.join(', ')}",
      status: :unprocessable_entity
    )
  end

  def render_conflict(_exception)
    render_api_error('Resource conflict', status: :conflict)
  end

  def render_bad_request(exception)
    render_api_error(exception.message, status: :bad_request)
  end
end
