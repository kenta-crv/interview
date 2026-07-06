require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe 'PLAN_CATALOG' do
    it 'includes trial and paid plans for LP' do
      expect(Subscription.public_plans.keys).to contain_exactly(:trial, :starter, :standard, :business, :enterprise)
    end

    it 'has expected trial limits' do
      config = Subscription.plan_config(:trial)
      expect(config[:price]).to eq(0)
      expect(config[:deal_limit]).to eq(3)
      expect(config[:service_limit]).to eq(1)
      expect(config[:post_trial_plan]).to eq(:standard)
    end

    it 'has expected starter limits and price' do
      config = Subscription.plan_config(:starter)
      expect(config[:price]).to eq(29_800)
      expect(config[:deal_limit]).to eq(15)
      expect(config[:service_limit]).to eq(1)
      expect(config[:click_analytics]).to be true
    end

    it 'marks standard as popular (blue highlight on LP)' do
      config = Subscription.plan_config(:standard)
      expect(config[:popular]).to be true
      expect(config[:featured]).to be false
    end

    it 'has expected business limits and featured flag' do
      config = Subscription.plan_config(:business)
      expect(config[:price]).to eq(98_000)
      expect(config[:deal_limit]).to eq(100)
      expect(config[:service_limit]).to eq(7)
      expect(config[:click_analytics]).to be true
      expect(config[:prospect_follow_up]).to be true
      expect(config[:featured]).to be true
    end

    it 'has unlimited deals for enterprise' do
      config = Subscription.plan_config(:enterprise)
      expect(config[:deal_limit]).to be_nil
      expect(config[:service_limit]).to eq(10)
      expect(config[:price]).to eq(198_000)
    end

    it 'returns nil for blank plan type' do
      expect(Subscription.plan_config(nil)).to be_nil
      expect(Subscription.plan_config("")).to be_nil
    end
  end

  describe '.format_feature_value' do
    it 'shows checkmark for business prospect follow up' do
      expect(Subscription.format_feature_value(:business, :prospect_follow_up)).to eq('✔︎')
    end

    it 'shows 近日公開 for enterprise prospect follow up' do
      expect(Subscription.format_feature_value(:enterprise, :prospect_follow_up)).to eq('近日公開')
    end
  end

  describe 'client without subscription' do
    let(:client) { Client.create!(email: "no-sub@example.com", password: "password123") }

    it 'falls back to trial plan config' do
      expect(client.current_plan_config[:deal_limit]).to eq(3)
    end
  end
end
