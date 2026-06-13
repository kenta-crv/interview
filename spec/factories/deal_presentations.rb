FactoryBot.define do
  factory :deal_presentation do
    deal { nil }
    situation { nil }
    status { 1 }
    current_step { "MyText" }
    user_choices { "" }
    guidance_history { "" }
  end
end
