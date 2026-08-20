require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe 'PLAN_CATALOG' do
    it 'returns LP display plans without starter' do
      expect(Subscription.lp_display_plans.map(&:first)).to eq(%i[trial standard business enterprise])
    end

    it 'has expected trial limits' do
      config = Subscription.plan_config(:trial)
      expect(config[:price]).to eq(0)
      expect(config[:deal_limit]).to eq(5)
      expect(config[:service_limit]).to eq(1)
      expect(config[:post_trial_plan]).to eq(:standard)
    end

    it 'hides starter from purchase and LP' do
      config = Subscription.plan_config(:starter)
      expect(config[:purchasable]).to be false
      expect(config[:public_on_lp]).to be false
    end

    it 'has multi-currency standard prices' do
      expect(Subscription.price_for(:standard, currency: :jpy)).to eq(59_800)
      expect(Subscription.price_for(:standard, currency: :usd)).to eq(399)
    end

    it 'marks standard as popular (blue highlight on LP)' do
      config = Subscription.plan_config(:standard)
      expect(config[:popular]).to be true
      expect(config[:featured]).to be false
    end

    it 'has expected business limits and featured flag' do
      config = Subscription.plan_config(:business)
      expect(config[:price]).to eq(98_000)
      expect(config[:deal_limit]).to eq(300)
      expect(config[:service_limit]).to eq(7)
      expect(config[:click_analytics]).to be true
      expect(config[:prospect_follow_up]).to be true
      expect(config[:featured]).to be true
    end

    it 'has unlimited deals for enterprise' do
      config = Subscription.plan_config(:enterprise)
      expect(config[:deal_limit]).to be_nil
      expect(config[:service_limit]).to eq(50)
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

    it 'formats deal and material limits' do
      expect(Subscription.format_feature_value(:trial, :deal_limit)).to eq('5')
      expect(Subscription.format_feature_value(:standard, :deal_limit)).to eq('50')
      expect(Subscription.format_feature_value(:enterprise, :deal_limit)).to eq('無制限')
      expect(Subscription.format_feature_value(:trial, :service_limit)).to eq('1')
    end

    it 'shows dashboard feature flags' do
      expect(Subscription.format_feature_value(:standard, :ai_voice_deal)).to eq('✔︎')
      expect(Subscription.format_feature_value(:standard, :priority_support)).to eq('✕')
      expect(Subscription.format_feature_value(:enterprise, :priority_support)).to eq('✔︎')
    end

    it 'exposes expanded comparison features' do
      expect(Subscription::LP_COMPARISON_FEATURES.map { |f| f[:key] }).to include(
        :deal_limit, :service_limit, :ai_voice_deal, :prospect_scoring, :deal_summary, :faq_chat, :priority_support
      )
    end
  end

  describe 'client without subscription' do
    let(:client) { create(:client, email: "no-sub@example.com") }

    it 'falls back to trial plan config' do
      expect(client.current_plan_config[:deal_limit]).to eq(5)
    end
  end
end
