# frozen_string_literal: true

# アップロードファイルのサイズ・Content-Type検証
module FileUploadValidation
  extend ActiveSupport::Concern

  AUDIO_CONTENT_TYPES = %w[
    audio/mpeg audio/mp3 audio/mp4 audio/wav audio/webm
    audio/x-wav audio/x-m4a audio/ogg
  ].freeze

  VIDEO_CONTENT_TYPES = %w[
    video/mp4 video/webm video/quicktime video/x-msvideo
  ].freeze

  private

  def validate_audio_upload!(file)
    return unless file
    max_size = Rails.application.config.interview.max_audio_size
    validate_upload!(file, allowed_types: AUDIO_CONTENT_TYPES, max_size: max_size, label: 'Audio')
  end

  def validate_video_upload!(file)
    return unless file
    max_size = Rails.application.config.interview.max_video_size
    validate_upload!(file, allowed_types: VIDEO_CONTENT_TYPES, max_size: max_size, label: 'Video')
  end

  def validate_upload!(file, allowed_types:, max_size:, label:)
    unless file.respond_to?(:content_type)
      raise ActionController::BadRequest, "#{label} file is invalid"
    end

    unless allowed_types.include?(file.content_type)
      raise ActionController::BadRequest,
        "#{label} file type '#{file.content_type}' not allowed. Accepted: #{allowed_types.join(', ')}"
    end

    if file.size > max_size
      raise ActionController::BadRequest,
        "#{label} file too large (#{(file.size.to_f / 1024 / 1024).round(1)}MB, max #{max_size / 1024 / 1024}MB)"
    end
  end
end
