# app/services/interview_engine/media_processor.rb
module InterviewEngine
  class MediaProcessor
    require 'tmpdir'

    def self.extract_audio_from_video(video_path)
      raise "Video file not found: #{video_path}" unless File.exist?(video_path)

      output_path = File.join(Dir.tmpdir, "audio_extract_#{Time.current.to_i}.wav")
      cmd = [
        'ffmpeg', '-y',
        '-i', video_path,
        '-vn',
        '-acodec', 'pcm_s16le',
        '-ar', '16000',
        '-ac', '1',
        output_path
      ]

      success = system(*cmd)
      raise 'ffmpeg failed to extract audio' unless success && File.exist?(output_path)

      output_path
    end
  end
end
