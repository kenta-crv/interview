FactoryBot.define do
  factory :question do
    association :situation
    sequence(:question_text) { |n| "テスト質問 #{n}" }
    question_type { 'descriptive' }
    sequence(:order) { |n| n }
    required { true }

    trait :multiple_choice do
      question_type { 'multiple_choice' }
      options { { 'choices' => ['選択肢A', '選択肢B', '選択肢C'] } }
    end

    trait :with_branching do
      branching_rules { { 'condition' => 'score_above', 'threshold' => 80, 'next_question_id' => nil } }
    end

    trait :optional do
      required { false }
    end
  end
end
