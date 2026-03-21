require 'rails_helper'

RSpec.describe InterviewEngine::SessionManager do
  let(:client) { create(:client) }
  let(:situation) { create(:situation, :with_questions, client: client) }
  let(:user) { create(:user) }
  let(:manager) { described_class.new(user, situation) }

  describe '#start_interview' do
    it '新しい面接を開始し、in_progressステータスで返す' do
      interview = manager.start_interview(language: 'ja')

      expect(interview).to be_in_progress
      expect(interview.user).to eq(user)
      expect(interview.situation).to eq(situation)
      expect(interview.language).to eq('ja')
      expect(interview.started_at).to be_present
      expect(interview.last_activity_at).to be_present
    end

    it 'デフォルト言語はenで開始する' do
      interview = manager.start_interview
      expect(interview.language).to eq('en')
    end

    it '既存のin_progress面接がある場合はそれを返す' do
      existing = manager.start_interview(language: 'ja')
      returned = manager.start_interview(language: 'ja')

      expect(returned.id).to eq(existing.id)
    end

    it '完了済みの面接がある場合はエラーを発生する' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      interview.complete!

      expect {
        manager.start_interview
      }.to raise_error(InterviewEngine::SessionManager::SessionError, /already completed/)
    end

    it '失敗済みの面接がある場合はエラーを発生する' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      interview.fail!

      expect {
        manager.start_interview
      }.to raise_error(InterviewEngine::SessionManager::SessionError, /already completed/)
    end

    it 'abandoned面接でresumable?の場合は復帰する' do
      interview = create(:interview, :abandoned, user: user, situation: situation)

      returned = manager.start_interview(language: 'ja')
      expect(returned.id).to eq(interview.id)
      expect(returned).to be_in_progress
    end

    it 'access_tokenが生成される' do
      interview = manager.start_interview
      expect(interview.access_token).to be_present
    end
  end

  describe '.start_by_token' do
    it '有効なトークンで面接を開始する' do
      interview = create(:interview, user: user, situation: situation)

      result = described_class.start_by_token(interview.access_token)
      expect(result).to be_in_progress
      expect(result.id).to eq(interview.id)
    end

    it '無効なトークンでSessionErrorを発生する' do
      expect {
        described_class.start_by_token('invalid_token')
      }.to raise_error(InterviewEngine::SessionManager::SessionError, /Invalid interview token/)
    end

    it 'in_progress面接のトークンでアクティビティを更新する' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      old_activity = interview.last_activity_at

      travel_to 1.minute.from_now do
        result = described_class.start_by_token(interview.access_token)
        expect(result.last_activity_at).to be > old_activity
      end
    end

    it '完了済み面接のトークンでSessionErrorを発生する' do
      interview = create(:interview, :completed, user: user, situation: situation)

      expect {
        described_class.start_by_token(interview.access_token)
      }.to raise_error(InterviewEngine::SessionManager::SessionError, /already ended/)
    end

    it 'タイムアウトしたin_progress面接でTimeoutErrorを発生する' do
      interview = create(:interview, :timed_out, user: user, situation: situation)

      expect {
        described_class.start_by_token(interview.access_token)
      }.to raise_error(InterviewEngine::SessionManager::TimeoutError)
    end

    it 'abandoned面接でresumable?の場合は復帰する' do
      interview = create(:interview, :abandoned, user: user, situation: situation)

      result = described_class.start_by_token(interview.access_token)
      expect(result).to be_in_progress
      expect(result.resume_count).to eq(1)
    end

    it 'abandoned面接でresume上限到達時にResumeErrorを発生する' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      interview.update_column(:resume_count, situation.max_resume_count)

      expect {
        described_class.start_by_token(interview.access_token)
      }.to raise_error(InterviewEngine::SessionManager::ResumeError)
    end
  end

  describe '#resume_interview' do
    it 'abandoned面接を再開する' do
      interview = create(:interview, :abandoned, user: user, situation: situation)

      result = manager.resume_interview(interview.id)
      expect(result).to be_in_progress
      expect(result.resume_count).to eq(1)
      expect(result.resumed_at).to be_present
    end

    it 'resumable?でない面接でResumeErrorを発生する' do
      interview = create(:interview, :completed, user: user, situation: situation)

      expect {
        manager.resume_interview(interview.id)
      }.to raise_error(InterviewEngine::SessionManager::ResumeError)
    end

    it 'resume上限に達している場合はResumeErrorを発生する' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      interview.update_column(:resume_count, situation.max_resume_count)

      expect {
        manager.resume_interview(interview.id)
      }.to raise_error(InterviewEngine::SessionManager::ResumeError)
    end

    it 'allow_resumeがfalseのsituationでResumeErrorを発生する' do
      no_resume_situation = create(:situation, :with_questions, :no_resume, client: client)
      interview = create(:interview, :abandoned, user: user, situation: no_resume_situation)
      no_resume_manager = described_class.new(user, no_resume_situation)

      expect {
        no_resume_manager.resume_interview(interview.id)
      }.to raise_error(InterviewEngine::SessionManager::ResumeError)
    end
  end

  describe '#touch_session' do
    it 'アクティビティを更新する' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      old_activity = interview.last_activity_at

      travel_to 1.minute.from_now do
        result = manager.touch_session(interview.id)
        expect(result.last_activity_at).to be > old_activity
      end
    end

    it 'タイムアウト時にTimeoutErrorを発生する' do
      interview = create(:interview, :timed_out, user: user, situation: situation)

      expect {
        manager.touch_session(interview.id)
      }.to raise_error(InterviewEngine::SessionManager::TimeoutError)
    end
  end

  describe '#check_timeout!' do
    it 'タイムアウトしていない場合は何も起きない' do
      interview = create(:interview, :in_progress, user: user, situation: situation)

      expect {
        manager.check_timeout!(interview.id)
      }.not_to raise_error
    end

    it 'タイムアウト時にabandonしてTimeoutErrorを発生する' do
      interview = create(:interview, :timed_out, user: user, situation: situation)

      expect {
        manager.check_timeout!(interview.id)
      }.to raise_error(InterviewEngine::SessionManager::TimeoutError)

      interview.reload
      expect(interview).to be_abandoned
    end

    it 'in_progressでない場合は何もしない' do
      interview = create(:interview, :completed, user: user, situation: situation)

      expect {
        manager.check_timeout!(interview.id)
      }.not_to raise_error
    end
  end

  describe '#get_interview_state' do
    it '面接の状態を正しく返す' do
      interview = create(:interview, :in_progress, user: user, situation: situation)

      state = manager.get_interview_state(interview.id)

      expect(state[:interview_id]).to eq(interview.id)
      expect(state[:status]).to eq('in_progress')
      expect(state[:progress]).to eq(0.0)
      expect(state[:answered_questions]).to eq(0)
      expect(state[:total_questions]).to eq(3)
      expect(state[:duration_seconds]).to be >= 0
      expect(state[:remaining_seconds]).to be_present
      expect(state[:resume_count]).to eq(0)
      expect(state[:resumable]).to be false
    end
  end

  describe '#fail_interview' do
    it '面接を失敗にしてInterviewResultを作成する' do
      interview = create(:interview, :in_progress, user: user, situation: situation)

      result = manager.fail_interview(interview.id, 'スコア不足')

      expect(result).to be true
      interview.reload
      expect(interview).to be_failed

      ir = interview.interview_result
      expect(ir).to be_present
      expect(ir).to be_failed
      expect(ir.results_data['failure_reason']).to eq('スコア不足')
    end

    it '既にInterviewResultがある場合は既存を返す' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      existing_result = create(:interview_result, interview: interview, final_status: :failed)

      result = manager.fail_interview(interview.id, 'duplicate')
      expect(result).to eq(existing_result)
    end
  end

  describe '#complete_interview' do
    it 'pending回答がある場合はSessionErrorを発生する' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      question = situation.questions.first
      create(:interview_response, interview: interview, question: question, evaluation_status: :pending)

      expect {
        manager.complete_interview(interview.id)
      }.to raise_error(InterviewEngine::SessionManager::SessionError, /pending evaluation/)
    end

    it '全回答が評価済みの場合はInterviewResultを作成する' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      situation.questions.each do |q|
        create(:interview_response, :evaluated, interview: interview, question: q)
      end

      # LLMのsummarize_interviewをモック
      llm_mock = instance_double(InterviewEngine::LLMClient)
      allow(InterviewEngine::LLMClient).to receive(:new).and_return(llm_mock)
      allow(llm_mock).to receive(:summarize_interview).and_return({
        summary: 'テスト要約',
        strengths: ['強み1'],
        weaknesses: ['弱み1'],
        recommendation: '採用推奨'
      })

      result = manager.complete_interview(interview.id)

      expect(result).to be_a(InterviewResult)
      expect(result.results_data['summary']).to eq('テスト要約')

      interview.reload
      expect(interview).to be_completed
    end
  end

  describe '.expire_timed_out_sessions!' do
    it 'タイムアウトした面接を一括abandonする' do
      timed_out = create(:interview, :timed_out, user: user, situation: situation)
      active = create(:interview, :in_progress, user: create(:user), situation: situation)

      described_class.expire_timed_out_sessions!

      timed_out.reload
      active.reload

      expect(timed_out).to be_abandoned
      expect(active).to be_in_progress
    end
  end
end
