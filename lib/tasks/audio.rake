# lib/tasks/audio.rake
namespace :audio do
  desc "Pre-generate TTS audio for all questions in a situation"
  task :pregenerate, [:situation_id] => :environment do |_t, args|
    situation_id = args[:situation_id]
    abort "Usage: rake audio:pregenerate[SITUATION_ID]" unless situation_id

    situation = Situation.find(situation_id)
    puts "Generating audio for Situation ##{situation.id}: #{situation.title}"
    puts "Language: #{situation.language}, Questions: #{situation.questions.count}"

    InterviewEngine::AudioInterviewService.pregenerate_question_audio(situation)
    puts "Done."
  end

  desc "Pre-generate TTS audio for all active situations"
  task pregenerate_all: :environment do
    Situation.active.find_each do |situation|
      puts "Processing Situation ##{situation.id}: #{situation.title}"
      InterviewEngine::AudioInterviewService.pregenerate_question_audio(situation)
    end
    puts "All done."
  end

  desc "Clean up old temporary audio files"
  task cleanup: :environment do
    dir = Rails.root.join('tmp', 'interview_audio')
    unless Dir.exist?(dir)
      puts "No temp audio directory found."
      next
    end

    threshold = 24.hours.ago
    count = 0

    Dir.glob(File.join(dir, '*.mp3')).each do |file|
      if File.mtime(file) < threshold
        File.delete(file)
        count += 1
      end
    end

    puts "Deleted #{count} old temp audio files from #{dir}."
  end

  desc "Clean up old temporary audio files from system temp directory"
  task cleanup_tmpdir: :environment do
    require 'tmpdir'
    tmpdir = Dir.tmpdir
    threshold = 24.hours.ago
    count = 0

    # MediaProcessor/TTSClient が生成する一時ファイルパターン
    %w[audio_extract_*.wav normalized_*.wav tts_*.mp3].each do |pattern|
      Dir.glob(File.join(tmpdir, pattern)).each do |file|
        if File.mtime(file) < threshold
          File.delete(file)
          count += 1
        end
      rescue => e
        puts "Warning: Failed to delete #{file}: #{e.message}"
      end
    end

    puts "Deleted #{count} old temp audio files from #{tmpdir}."
  end
end
