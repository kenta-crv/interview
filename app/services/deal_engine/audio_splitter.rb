# app/services/deal_engine/audio_splitter.rb
module DealEngine
  class AudioSplitter
    class SplitError < StandardError; end

    SEGMENT_DURATION_SECONDS = 300 # 5 minutes per segment
    OVERLAP_SECONDS = 5 # 5 seconds overlap between segments

    def initialize(deal_audio)
      @deal_audio = deal_audio
    end

    def split!
      validate_audio_file!

      audio_file = @deal_audio.audio_file
      audio_path = download_temp_file(audio_file)

      begin
        segments_info = get_audio_info(audio_path)
        total_duration = segments_info[:duration]

        segments = create_segments(total_duration)
        split_audio(audio_path, segments)

        @deal_audio.update!(
          duration_seconds: total_duration.to_i,
          segment_count: segments.count
        )

        segments
      ensure
        File.delete(audio_path) if File.exist?(audio_path)
      end
    end

    private

    def validate_audio_file!
      unless @deal_audio.audio_file.attached?
        raise SplitError, "No audio file attached"
      end
    end

    def download_temp_file(audio_file)
      temp_dir = Dir.mktmpdir
      temp_path = File.join(temp_dir, "original_#{audio_file.filename.basename}")
      File.open(temp_path, 'wb') do |file|
        file.write(audio_file.download)
      end
      temp_path
    end

    def get_audio_info(audio_path)
      cmd = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"#{audio_path}\""
      output = `#{cmd}`

      if output.empty?
        raise SplitError, "Failed to get audio duration"
      end

      duration = output.strip.to_f
      { duration: duration }
    rescue => e
      raise SplitError, "Failed to get audio info: #{e.message}"
    end

    def create_segments(total_duration)
      segments = []
      current_time = 0
      segment_number = 1

      while current_time < total_duration
        end_time = [current_time + SEGMENT_DURATION_SECONDS + OVERLAP_SECONDS, total_duration].min
        duration = end_time - current_time

        segments << {
          segment_number: segment_number,
          start_time: current_time,
          end_time: end_time,
          duration_seconds: duration.to_i
        }

        current_time = end_time - OVERLAP_SECONDS
        segment_number += 1
      end

      segments
    end

    def split_audio(audio_path, segments)
      temp_dir = File.dirname(audio_path)

      segments.each do |segment_info|
        segment = DealSegment.create!(
          deal_audio: @deal_audio,
          segment_number: segment_info[:segment_number],
          start_time: segment_info[:start_time],
          end_time: segment_info[:end_time],
          duration_seconds: segment_info[:duration_seconds],
          transcription_status: :pending
        )

        output_path = File.join(temp_dir, "segment_#{segment.id}.wav")
        extract_segment(audio_path, output_path, segment_info)

        # Attach segment audio file
        File.open(output_path, 'rb') do |file|
          segment.audio_file.attach(
            io: file,
            filename: "segment_#{segment.id}.wav",
            content_type: 'audio/wav'
          )
        end

        File.delete(output_path) if File.exist?(output_path)
      end
    end

    def extract_segment(input_path, output_path, segment_info)
      cmd = [
        'ffmpeg',
        '-y', # Overwrite output file
        '-i', input_path,
        '-ss', segment_info[:start_time].to_s,
        '-t', segment_info[:duration_seconds].to_s,
        '-c', 'copy', # Copy codec without re-encoding
        output_path
      ].join(' ')

      output = `#{cmd} 2>&1`

      unless $?.success?
        raise SplitError, "Failed to extract segment: #{output}"
      end
    end
  end
end
