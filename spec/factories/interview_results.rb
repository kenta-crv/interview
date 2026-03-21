FactoryBot.define do
  factory :interview_result do
    association :interview
    final_status { :passed }
    results_data do
      {
        'total_questions' => 3,
        'answered_questions' => 3,
        'skipped_questions' => 0,
        'average_score' => 80.0,
        'summary' => 'テスト結果サマリー',
        'strengths' => ['コミュニケーション能力'],
        'weaknesses' => ['技術的知識'],
        'recommendation' => '採用推奨'
      }
    end

    trait :failed do
      final_status { :failed }
      results_data do
        {
          'total_questions' => 3,
          'answered_questions' => 3,
          'average_score' => 40.0,
          'summary' => '不合格'
        }
      end
    end

    trait :with_rejection do
      rejection_details do
        {
          'reason' => 'スコア不足',
          'rejected_at' => Time.current.iso8601,
          'details' => '合格基準を満たしませんでした'
        }
      end
    end
  end
end
