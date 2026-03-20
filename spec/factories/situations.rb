FactoryBot.define do
  factory :situation do
    association :client
    title { 'テスト面接シナリオ' }
    description { 'テスト用の面接シナリオです' }
    language { 'ja' }
    archived { false }
    session_timeout_minutes { 60 }
    allow_resume { true }
    max_resume_count { 3 }
    passing_score { 70 }
    auto_reject_enabled { true }
    reject_on_required_fail { true }
    min_required_score { 70 }
    max_consecutive_fails { 0 }
    reject_notify_method { 'in_app' }

    trait :with_questions do
      after(:create) do |situation|
        create_list(:question, 3, situation: situation)
      end
    end

    trait :no_resume do
      allow_resume { false }
    end

    trait :short_timeout do
      session_timeout_minutes { 1 }
    end
  end
end
