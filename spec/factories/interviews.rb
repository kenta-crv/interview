FactoryBot.define do
  factory :interview do
    association :user
    association :situation
    status { :not_started }
    language { 'ja' }
    resume_count { 0 }

    trait :in_progress do
      after(:create) do |interview|
        interview.start!
      end
    end

    trait :completed do
      after(:create) do |interview|
        interview.start!
        interview.complete!
      end
    end

    trait :failed do
      after(:create) do |interview|
        interview.start!
        interview.fail!
      end
    end

    trait :abandoned do
      after(:create) do |interview|
        interview.start!
        interview.abandon!
      end
    end

    trait :timed_out do
      after(:create) do |interview|
        interview.start!
        interview.update_column(:last_activity_at, 2.hours.ago)
      end
    end

    trait :rejected do
      rejection_reason { 'スコア不足' }
      rejected_at { Time.current }
    end
  end
end
