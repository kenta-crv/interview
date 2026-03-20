FactoryBot.define do
  factory :client do
    sequence(:email) { |n| "client#{n}@example.com" }
    password { 'password123' }
  end
end
