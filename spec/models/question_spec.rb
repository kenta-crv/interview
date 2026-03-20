require 'rails_helper'

RSpec.describe Question, type: :model do
  let(:client) { create(:client) }
  let(:situation) { create(:situation, client: client) }

  describe 'associations' do
    it { is_expected.to belong_to(:situation) }
    it { is_expected.to have_many(:interview_responses).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:question_text) }
    it { is_expected.to validate_presence_of(:question_type) }
  end

  describe '#multiple_choice?' do
    it 'returns true for choice type' do
      question = build(:question, question_type: 'choice')
      expect(question.multiple_choice?).to be true
    end

    it 'returns true for multiple_choice type' do
      question = build(:question, :multiple_choice)
      expect(question.multiple_choice?).to be true
    end

    it 'returns true for mcq type' do
      question = build(:question, question_type: 'mcq')
      expect(question.multiple_choice?).to be true
    end

    it 'returns false for descriptive type' do
      question = build(:question, question_type: 'descriptive')
      expect(question.multiple_choice?).to be false
    end
  end

  describe '#descriptive?' do
    it 'returns true for non-choice types' do
      question = build(:question, question_type: 'descriptive')
      expect(question.descriptive?).to be true
    end

    it 'returns false for choice types' do
      question = build(:question, :multiple_choice)
      expect(question.descriptive?).to be false
    end
  end

  describe '#has_branching_rules?' do
    it 'returns true when branching_rules present' do
      question = build(:question, :with_branching, situation: situation)
      expect(question.has_branching_rules?).to be true
    end

    it 'returns false when no branching_rules' do
      question = build(:question, situation: situation)
      expect(question.has_branching_rules?).to be false
    end
  end

  describe '#parsed_branching_rules' do
    it 'returns symbolized hash' do
      question = build(:question, :with_branching, situation: situation)
      rules = question.parsed_branching_rules
      expect(rules).to be_a(Hash)
      expect(rules[:condition]).to eq('score_above')
    end

    it 'returns nil when no rules' do
      question = build(:question, situation: situation)
      expect(question.parsed_branching_rules).to be_nil
    end
  end

  describe '#parsed_options' do
    it 'returns options hash for multiple choice' do
      question = build(:question, :multiple_choice, situation: situation)
      options = question.parsed_options
      expect(options['choices']).to eq(['選択肢A', '選択肢B', '選択肢C'])
    end

    it 'returns empty hash when no options' do
      question = build(:question, situation: situation)
      expect(question.parsed_options).to eq({})
    end
  end

  describe 'options_required_for_multiple_choice validation' do
    it 'requires choices for multiple_choice type' do
      question = build(:question, question_type: 'multiple_choice', options: nil, situation: situation)
      expect(question).not_to be_valid
      expect(question.errors[:options]).to include('must include choices for multiple choice questions')
    end

    it 'is valid with choices' do
      question = build(:question, :multiple_choice, situation: situation)
      expect(question).to be_valid
    end
  end

  describe 'scopes' do
    before do
      create(:question, situation: situation, order: 2)
      create(:question, situation: situation, order: 1)
      create(:question, situation: situation, order: 3)
    end

    it '.ordered returns questions in order' do
      questions = situation.questions.ordered
      expect(questions.map(&:order)).to eq([1, 2, 3])
    end
  end
end
