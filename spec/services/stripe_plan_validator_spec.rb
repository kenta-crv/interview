require 'rails_helper'

RSpec.describe StripePlanValidator do
  describe '.plan_type_for_price_id' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('STRIPE_PRICE_STARTER').and_return('price_starter')
      allow(ENV).to receive(:[]).with('STRIPE_PRICE_STANDARD').and_return('price_standard')
      allow(ENV).to receive(:[]).with('STRIPE_PRICE_ENTERPRISE').and_return('price_enterprise')
    end

    it 'maps price id to plan type' do
      expect(described_class.plan_type_for_price_id('price_starter')).to eq('starter')
      expect(described_class.plan_type_for_price_id('price_standard')).to eq('standard')
    end
  end

  describe '.collect_errors' do
    it 'reports missing env keys' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('STRIPE_PRICE_STARTER').and_return(nil)

      errors = described_class.collect_errors(:starter)
      expect(errors.first).to include('STRIPE_PRICE_STARTER')
    end
  end
end
