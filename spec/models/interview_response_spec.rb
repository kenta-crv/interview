require 'rails_helper'

RSpec.describe InterviewResponse, type: :model do
  let(:client) { create(:client) }
  let(:situation) { create(:situation, :with_questions, client: client) }
  let(:user) { create(:user) }
  let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }
  let(:question) { situation.questions.first }

  describe 'associations' do
    it { is_expected.to belong_to(:interview) }
    it { is_expected.to belong_to(:question) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:interview_id) }
    it { is_expected.to validate_presence_of(:question_id) }
  end

  describe 'enums' do
    it do
      is_expected.to define_enum_for(:evaluation_status).with_values(
        pending: 0, evaluating: 1, completed: 2, failed: 3
      )
    end
  end

  describe '#score' do
    it 'returns final_score from evaluation_data' do
      response = create(:interview_response, :evaluated, interview: interview, question: question)
      expect(response.score).to eq(80.0)
    end

    it 'returns nil when not evaluated' do
      response = create(:interview_response, interview: interview, question: question)
      expect(response.score).to be_nil
    end
  end

  describe '#passed_evaluation?' do
    it 'returns true when passed' do
      response = create(:interview_response, :evaluated, interview: interview, question: question)
      expect(response.passed_evaluation?).to be true
    end

    it 'returns false when failed' do
      response = create(:interview_response, :failed_evaluation, interview: interview, question: question)
      expect(response.passed_evaluation?).to be false
    end

    it 'returns false when not evaluated' do
      response = create(:interview_response, interview: interview, question: question)
      expect(response.passed_evaluation?).to be false
    end
  end

  describe '#evaluated?' do
    it 'returns true when evaluation is completed' do
      response = create(:interview_response, :evaluated, interview: interview, question: question)
      expect(response.evaluated?).to be true
    end

    it 'returns false when pending' do
      response = create(:interview_response, interview: interview, question: question)
      expect(response.evaluated?).to be false
    end
  end

  describe 'evaluation_data store' do
    it 'stores and retrieves individual scores' do
      response = create(:interview_response, :evaluated, interview: interview, question: question)
      expect(response.relevance_score).to eq(80)
      expect(response.correctness_score).to eq(75)
      expect(response.clarity_score).to eq(85)
      expect(response.evaluation_feedback).to eq('良い回答です')
    end
  end
end
