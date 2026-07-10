FactoryBot.define do
  factory :client do
    sequence(:email) { |n| "client#{n}@example.com" }
    password { 'password123' }
    company { "テスト株式会社" }
    name { "テスト太郎" }
    tel { "03-1234-5678" }
    address { "東京都渋谷区1-1-1" }
  end
end
