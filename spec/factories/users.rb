FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    name { 'テストユーザー' }
    job_title { '担当者' }
  end
end
