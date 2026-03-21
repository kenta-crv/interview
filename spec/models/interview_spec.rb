require 'rails_helper'

RSpec.describe Interview, type: :model do
  let(:client) { create(:client) }
  let(:situation) { create(:situation, :with_questions, client: client) }
  let(:user) { create(:user) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:situation) }
    it { is_expected.to have_many(:interview_responses).dependent(:destroy) }
    it { is_expected.to have_one(:interview_result).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:interview, user: user, situation: situation) }

    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:situation_id) }
    it { is_expected.to validate_presence_of(:language) }
  end

  describe 'enums' do
    it do
      is_expected.to define_enum_for(:status).with_values(
        not_started: 0, in_progress: 1, completed: 2, failed: 3, abandoned: 4
      )
    end
  end

  describe 'access_token' do
    it 'is generated on create' do
      interview = create(:interview, user: user, situation: situation)
      expect(interview.access_token).to be_present
      expect(interview.access_token.length).to be > 20
    end

    it 'is unique' do
      interview1 = create(:interview, user: user, situation: situation)
      user2 = create(:user)
      situation2 = create(:situation, :with_questions, client: client)
      interview2 = create(:interview, user: user2, situation: situation2)
      expect(interview1.access_token).not_to eq(interview2.access_token)
    end
  end

  describe 'uniqueness validation' do
    it 'prevents duplicate user+situation combination' do
      create(:interview, user: user, situation: situation)
      duplicate = build(:interview, user: user, situation: situation)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('can only interview once per situation')
    end
  end

  describe '#start!' do
    it 'transitions from not_started to in_progress' do
      interview = create(:interview, user: user, situation: situation)
      interview.start!
      expect(interview).to be_in_progress
      expect(interview.started_at).to be_present
      expect(interview.last_activity_at).to be_present
    end
  end

  describe '#complete!' do
    it 'transitions from in_progress to completed' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      interview.complete!
      expect(interview).to be_completed
      expect(interview.ended_at).to be_present
    end
  end

  describe '#fail!' do
    it 'transitions from in_progress to failed' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      interview.fail!
      expect(interview).to be_failed
      expect(interview.ended_at).to be_present
    end
  end

  describe '#abandon!' do
    it 'transitions from in_progress to abandoned' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      interview.abandon!
      expect(interview).to be_abandoned
    end
  end

  describe 'status transition validation' do
    it 'rejects invalid transitions' do
      interview = create(:interview, :completed, user: user, situation: situation)
      interview.status = :in_progress
      expect(interview).not_to be_valid
      expect(interview.errors[:status]).to include('cannot transition from completed to in_progress')
    end

    it 'rejects not_started to completed' do
      interview = create(:interview, user: user, situation: situation)
      interview.status = :completed
      expect(interview).not_to be_valid
    end

    it 'allows abandoned to in_progress' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      interview.status = :in_progress
      expect(interview).to be_valid
    end
  end

  describe '#timed_out?' do
    it 'returns true when session has expired' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      interview.update_column(:last_activity_at, 2.hours.ago)
      expect(interview.timed_out?).to be true
    end

    it 'returns false when session is active' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      expect(interview.timed_out?).to be false
    end

    it 'returns false when not in_progress' do
      interview = create(:interview, user: user, situation: situation)
      expect(interview.timed_out?).to be false
    end
  end

  describe '#resumable?' do
    it 'returns true for abandoned interview with resume allowed' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      expect(interview.resumable?).to be true
    end

    it 'returns false when resume count exceeds max' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      interview.update_column(:resume_count, situation.max_resume_count)
      expect(interview.resumable?).to be false
    end

    it 'returns false when situation disallows resume' do
      no_resume_situation = create(:situation, :with_questions, :no_resume, client: client)
      interview = create(:interview, :abandoned, user: user, situation: no_resume_situation)
      expect(interview.resumable?).to be false
    end

    it 'returns false for completed interview' do
      interview = create(:interview, :completed, user: user, situation: situation)
      expect(interview.resumable?).to be false
    end
  end

  describe '#resume!' do
    it 'resumes an abandoned interview' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      interview.resume!
      expect(interview).to be_in_progress
      expect(interview.resume_count).to eq(1)
      expect(interview.resumed_at).to be_present
      expect(interview.ended_at).to be_nil
    end

    it 'raises error when not resumable' do
      interview = create(:interview, :completed, user: user, situation: situation)
      expect { interview.resume! }.to raise_error(RuntimeError, 'Interview cannot be resumed')
    end
  end

  describe '#rejected?' do
    it 'returns true when rejection info is present' do
      interview = create(:interview, :rejected, user: user, situation: situation)
      expect(interview.rejected?).to be true
    end

    it 'returns false when not rejected' do
      interview = create(:interview, user: user, situation: situation)
      expect(interview.rejected?).to be false
    end
  end

  describe '#duration' do
    it 'calculates duration in seconds' do
      interview = create(:interview, :completed, user: user, situation: situation)
      interview.update_columns(started_at: 30.minutes.ago, ended_at: Time.current)
      expect(interview.duration).to be_within(2).of(1800)
    end

    it 'returns nil when not started' do
      interview = create(:interview, user: user, situation: situation)
      expect(interview.duration).to be_nil
    end
  end

  describe '#progress_percentage' do
    it 'calculates correct percentage' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      question = situation.questions.first
      create(:interview_response, interview: interview, question: question)

      expect(interview.progress_percentage).to eq(33.33)
    end

    it 'returns 0 when no questions answered' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      expect(interview.progress_percentage).to eq(0)
    end
  end

  describe 'ensure_situation_has_questions validation' do
    it 'rejects interview when situation has no questions' do
      empty_situation = create(:situation, client: client)
      interview = build(:interview, user: user, situation: empty_situation)
      expect(interview).not_to be_valid
      expect(interview.errors[:situation]).to include('must have at least 1 question')
    end
  end
end
