require 'rails_helper'

RSpec.describe InterviewResult, type: :model do
  let(:client) { create(:client) }
  let(:situation) { create(:situation, :with_questions, client: client) }
  let(:user) { create(:user) }
  let(:interview) { create(:interview, :completed, user: user, situation: situation) }

  describe 'associations' do
    it { is_expected.to belong_to(:interview) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:interview_id) }
  end

  describe 'enums' do
    it do
      is_expected.to define_enum_for(:final_status).with_values(
        passed: 0, failed: 1, incomplete: 2
      )
    end
  end

  describe '#completion_percentage' do
    it 'calculates correct percentage' do
      result = create(:interview_result, interview: interview, results_data: {
        'total_questions' => 10, 'answered_questions' => 7
      })
      expect(result.completion_percentage).to eq(70.0)
    end

    it 'returns 0 when total_questions is zero' do
      result = create(:interview_result, interview: interview, results_data: {
        'total_questions' => 0, 'answered_questions' => 0
      })
      expect(result.completion_percentage).to eq(0)
    end

    it 'returns 0 when total_questions is nil' do
      result = create(:interview_result, interview: interview, results_data: {})
      expect(result.completion_percentage).to eq(0)
    end
  end

  describe '#rejected?' do
    it 'returns true when rejection_details present' do
      result = create(:interview_result, :with_rejection, interview: interview)
      expect(result.rejected?).to be true
    end

    it 'returns false when rejection_details empty' do
      result = create(:interview_result, interview: interview)
      expect(result.rejected?).to be false
    end
  end

  describe 'results_data store' do
    it 'stores and retrieves values' do
      result = create(:interview_result, interview: interview)
      expect(result.total_questions).to eq(3)
      expect(result.average_score).to eq(80.0)
      expect(result.strengths).to eq(['コミュニケーション能力'])
      expect(result.recommendation).to eq('採用推奨')
    end
  end

  describe 'uniqueness' do
    it 'prevents duplicate results for same interview' do
      create(:interview_result, interview: interview)
      duplicate = build(:interview_result, interview: interview)
      expect(duplicate).not_to be_valid
    end
  end
end
