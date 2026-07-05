require "rails_helper"

RSpec.describe DealFaq, type: :model do
  let(:client) { Client.create!(email: "faq-test@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Test Deal", language: "ja") }

  it "requires a question" do
    faq = deal.deal_faqs.build(question: "", category: "other")
    expect(faq).not_to be_valid
  end

  it "scopes approved faqs for conversation" do
    deal.deal_faqs.create!(question: "Q1", answer: "A1", category: "pricing", status: "approved")
    deal.deal_faqs.create!(question: "Q2", answer: nil, category: "other", status: "pending")

    expect(deal.approved_faqs_for_conversation.count).to eq(1)
  end
end

RSpec.describe Deal, type: :model do
  let(:client) { Client.create!(email: "deal-faq@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Coverage Deal", language: "ja") }

  describe "#knowledge_coverage_percent" do
    it "returns 100 when no suggested faqs exist" do
      expect(deal.knowledge_coverage_percent).to eq(100)
    end

    it "calculates coverage from template and ai_gap faqs" do
      deal.deal_faqs.create!(question: "Q1", answer: "A1", category: "pricing", source: "template", status: "approved")
      deal.deal_faqs.create!(question: "Q2", answer: nil, category: "other", source: "ai_gap", status: "pending")

      expect(deal.knowledge_coverage_percent).to eq(50)
    end
  end
end

RSpec.describe DealEngine::FaqTemplateService do
  let(:client) { Client.create!(email: "template@example.com", password: "password123") }
  let(:deal) { client.deals.create!(title: "Template Deal", language: "ja") }

  it "seeds template faqs when empty" do
    described_class.new(deal).seed_if_empty!
    expect(deal.deal_faqs.count).to eq(3)
    expect(deal.deal_faqs.pluck(:source).uniq).to eq(["template"])
  end

  it "does not duplicate when faqs already exist" do
    deal.deal_faqs.create!(question: "Existing", answer: "A", category: "other", status: "approved")
    described_class.new(deal).seed_if_empty!
    expect(deal.deal_faqs.count).to eq(1)
  end
end
