FactoryBot.define do
  factory :interview_response do
    association :interview
    association :question
    audio_transcript { 'テスト回答の音声トランスクリプト' }
    evaluation_status { :pending }

    trait :evaluated do
      evaluation_status { :completed }
      evaluation_data do
        {
          'relevance_score' => 80,
          'correctness_score' => 75,
          'clarity_score' => 85,
          'final_score' => 80,
          'evaluation_feedback' => '良い回答です',
          'passed' => true,
          'ai_reasoning' => '回答は質問に対して適切でした'
        }
      end
    end

    trait :failed_evaluation do
      evaluation_status { :completed }
      evaluation_data do
        {
          'relevance_score' => 30,
          'correctness_score' => 25,
          'clarity_score' => 35,
          'final_score' => 30,
          'evaluation_feedback' => '回答が不十分です',
          'passed' => false,
          'ai_reasoning' => '質問に対する回答が不足しています'
        }
      end
    end
  end
end
