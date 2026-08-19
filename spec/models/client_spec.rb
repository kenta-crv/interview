require 'rails_helper'

RSpec.describe Client, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:situations) }
  end

  describe 'validations' do
    it 'requires email' do
      client = build(:client, email: '')
      expect(client).not_to be_valid
      expect(client.errors[:email]).to be_present
    end

    it 'requires unique email' do
      create(:client, email: 'client@example.com')
      client = build(:client, email: 'client@example.com')
      expect(client).not_to be_valid
      expect(client.errors[:email]).to be_present
    end

    it 'requires valid email format' do
      client = build(:client, email: 'not-an-email')
      expect(client).not_to be_valid
    end

    it 'requires password with minimum length' do
      client = build(:client, password: 'short')
      expect(client).not_to be_valid
      expect(client.errors[:password]).to be_present
    end

    it 'creates with valid attributes' do
      client = build(:client)
      expect(client).to be_valid
    end
  end

  describe 'Devise modules' do
    it 'includes expected modules' do
      expected_modules = [:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable]
      expected_modules.each do |mod|
        expect(Client.devise_modules).to include(mod)
      end
    end
  end

  describe 'situations association' do
    it 'can have multiple situations' do
      client = create(:client)
      situation1 = create(:situation, client: client, title: 'シナリオ1')
      situation2 = create(:situation, client: client, title: 'シナリオ2')

      expect(client.situations).to include(situation1, situation2)
      expect(client.situations.count).to eq(2)
    end
  end

  describe '#intro_discount_eligible?' do
    it 'is true during trial before a paid plan' do
      client = create(:client)
      expect(client).to be_intro_discount_eligible
    end

    it 'is false after any paid plan exists' do
      client = create(:client)
      client.subscriptions.create!(plan_type: :standard, status: :cancelled)
      expect(client).not_to be_intro_discount_eligible
    end
  end

  describe '#trial_start_available?' do
    it 'is false once a trial subscription exists' do
      client = create(:client)
      expect(client).not_to be_trial_start_available
    end
  end
end
