#!/usr/bin/env ruby
require_relative 'config/environment'

# Reset interview 1 to test complete flow
interview = Interview.find(1)
interview.update(status: 0)
interview.interview_responses.delete_all
interview.interview_results.delete_all

puts "✅ Interview reset"

# Create all 3 responses with evaluated status
r1 = interview.interview_responses.create!(
  question_id: 1,
  audio_transcript: "I have 10 years of database experience",
  evaluation_status: :completed,
  evaluation_data: {
    relevance_score: 85,
    correctness_score: 90,
    clarity_score: 88,
    final_score: 87.8,
    passed: true
  }
)

r2 = interview.interview_responses.create!(
  question_id: 2,
  audio_transcript: "System design requires careful consideration",
  evaluation_status: :completed,
  evaluation_data: {
    relevance_score: 80,
    correctness_score: 85,
    clarity_score: 82,
    final_score: 82.2,
    passed: true
  }
)

r3 = interview.interview_responses.create!(
  question_id: 3,
  audio_transcript: "Built a real-time data pipeline",
  evaluation_status: :completed,
  evaluation_data: {
    relevance_score: 88,
    correctness_score: 92,
    clarity_score: 85,
    final_score: 89.0,
    passed: true
  }
)

interview.update(status: 1)
puts "✅ Responses created: #{r1.id}, #{r2.id}, #{r3.id}"
puts "✅ Ready to test complete endpoint"
