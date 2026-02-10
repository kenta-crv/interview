interview = Interview.find(1)
interview.update(status: 0)
interview.interview_responses.delete_all
interview.interview_results.delete_all

3.times.each_with_index do |i|
  q_id = i + 1
  interview.interview_responses.create!(
    question_id: q_id,
    audio_transcript: "Test answer for question #{q_id}",
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

interview.update(status: 1)
puts "✅ Test data ready"
