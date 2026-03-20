# app/services/interview_engine/media_processor.rb
require 'tmpdir'
require 'open3'

module InterviewEngine
  class MediaProcessor
    class MediaError < StandardError; end

    class << self
      private

      def config
        Rails.application.config.interview
      end
    end

    # 動画から音声を抽出（WAV 16kHz mono）
    def self.extract_audio_from_video(video_path)
      validate_input!(video_path)
      ensure_ffmpeg!

      output_path = File.join(Dir.tmpdir, "audio_extract_#{SecureRandom.hex(8)}.wav")
      cmd = [
        'ffmpeg', '-y',
        '-i', video_path,
        '-vn',
        '-acodec', 'pcm_s16le',
        '-ar', '16000',
        '-ac', '1',
        output_path
      ]

      stdout, stderr, status = execute_with_timeout(cmd)

      unless status&.success? && File.exist?(output_path)
        Rails.logger.error("ffmpeg failed: #{stderr}")
        raise MediaError, "Failed to extract audio from video"
      end

      if File.size(output_path).zero?
        File.delete(output_path) if File.exist?(output_path)
        raise MediaError, "Extracted audio is empty"
      end

      output_path
    end

    # 音声ファイルの長さ（秒）を取得
    def self.audio_duration(audio_path)
      ensure_ffmpeg!
      raise MediaError, "File not found: #{audio_path}" unless File.exist?(audio_path)

      cmd = [
        'ffprobe',
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        audio_path
      ]

      stdout, stderr, status = Open3.capture3(*cmd)
      unless status.success?
        Rails.logger.warn("ffprobe failed: #{stderr}")
        return nil
      end

      stdout.strip.to_f
    end

    # 音声の長さをバリデーション
    def self.validate_audio_duration!(audio_path)
      duration = audio_duration(audio_path)
      return if duration.nil? # ffprobeが使えない場合はスキップ

      if duration < config.min_audio_duration
        raise MediaError, "Audio too short (#{duration.round(1)}s, min #{config.min_audio_duration}s)"
      end

      if duration > config.max_audio_duration
        raise MediaError, "Audio too long (#{duration.round(0)}s, max #{config.max_audio_duration}s)"
      end
    end

    # 音声フォーマットを WAV 16kHz mono に変換（STT最適化）
    def self.normalize_audio(audio_path)
      ensure_ffmpeg!
      raise MediaError, "File not found: #{audio_path}" unless File.exist?(audio_path)

      output_path = File.join(Dir.tmpdir, "normalized_#{SecureRandom.hex(8)}.wav")
      cmd = [
        'ffmpeg', '-y',
        '-i', audio_path,
        '-acodec', 'pcm_s16le',
        '-ar', '16000',
        '-ac', '1',
        output_path
      ]

      stdout, stderr, status = execute_with_timeout(cmd)
      unless status&.success? && File.exist?(output_path) && File.size(output_path) > 0
        File.delete(output_path) if File.exist?(output_path)
        raise MediaError, "Failed to normalize audio"
      end

      output_path
    end

    def self.validate_input!(path)
      raise MediaError, "Video file not found: #{path}" unless File.exist?(path)

      size = File.size(path)
      raise MediaError, "Video file is empty" if size.zero?
      max_size = config.max_video_size
      raise MediaError, "Video file too large (#{(size / 1024.0 / 1024).round(1)}MB, max #{max_size / 1024 / 1024}MB)" if size > max_size
    end

    def self.ensure_ffmpeg!
      # falseの場合は毎回再チェックする（後からffmpegがインストールされた場合に対応）
      unless @ffmpeg_available
        @ffmpeg_available = system('ffmpeg', '-version', out: File::NULL, err: File::NULL)
      end
      raise MediaError, "ffmpeg is not installed or not in PATH" unless @ffmpeg_available
    end

    def self.execute_with_timeout(cmd)
      Open3.capture3(*cmd, timeout: config.ffmpeg_timeout)
    rescue Timeout::Error
      raise MediaError, "ffmpeg timed out after #{config.ffmpeg_timeout}s"
    end

    private_class_method :validate_input!, :ensure_ffmpeg!, :execute_with_timeout
  end
end
