Interview.find(1).interview_responses.delete_all
Interview.find(1).interview_result&.delete
Interview.find(1).update(status: :not_started)

i = Interview.find(1)

(1..3).each do |q_id|
  i.interview_responses.create!(
    question_id: q_id,
    audio_transcript: "Answer to question #{q_id}",
    evaluation_status: :completed,
    evaluation_data: {
      relevance_score: 85,
      correctness_score: 88,
      clarity_score: 86,
      final_score: 86.3,
      passed: true
    }
  )
end

i.update(status: :in_progress)
puts "✅ Ready for complete test"
