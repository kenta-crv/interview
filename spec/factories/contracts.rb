FactoryBot.define do
  factory :contract do
    user { nil }
    company { "MyString" }
    name { "MyString" }
    tel { "MyString" }
    email { "MyString" }
    address { "MyString" }
    url { "MyString" }
    service { "MyString" }
    period { "MyString" }
    message { "MyText" }
  end
end
