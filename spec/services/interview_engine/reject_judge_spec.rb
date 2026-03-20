require 'rails_helper'

RSpec.describe InterviewEngine::RejectJudge do
  let(:client) { create(:client) }
  let(:situation) do
    create(:situation, :with_questions, client: client,
           auto_reject_enabled: true,
           reject_on_required_fail: true,
           min_required_score: 60,
           max_consecutive_fails: 3,
           passing_score: 70)
  end
  let(:user) { create(:user) }
  let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }
  let(:judge) { described_class.new(interview) }

  describe '#judge_after_response' do
    context 'auto_rejectが無効' do
      let(:no_reject_situation) do
        create(:situation, :with_questions, client: client, auto_reject_enabled: false)
      end
      let(:no_reject_interview) do
        create(:interview, :in_progress, user: create(:user), situation: no_reject_situation)
      end
      let(:no_reject_judge) { described_class.new(no_reject_interview) }

      it 'リジェクトしない' do
        question = no_reject_situation.questions.first
        response = create(:interview_response, :failed_evaluation, interview: no_reject_interview, question: question)

        decision = no_reject_judge.judge_after_response(response)
        expect(decision).not_to be_rejected
      end
    end

    context '必須質問の不合格' do
      it '必須質問のスコアが基準未満の場合はリジェクトする' do
        question = situation.questions.first
        question.update!(required: true)

        response = create(:interview_response, interview: interview, question: question,
                          evaluation_status: :completed,
                          evaluation_data: { 'final_score' => 50, 'passed' => false })

        decision = judge.judge_after_response(response)
        expect(decision).to be_rejected
        expect(decision.reason).to include('必須質問')
        expect(decision.details[:reason_code]).to eq('required_question_failed')
      end

      it '必須質問のスコアが基準以上の場合はリジェクトしない' do
        question = situation.questions.first
        question.update!(required: true)

        response = create(:interview_response, interview: interview, question: question,
                          evaluation_status: :completed,
                          evaluation_data: { 'final_score' => 80, 'passed' => true })

        decision = judge.judge_after_response(response)
        expect(decision).not_to be_rejected
      end

      it 'reject_on_required_failがfalseの場合はリジェクトしない' do
        situation.update!(reject_on_required_fail: false)
        question = situation.questions.first
        question.update!(required: true)

        response = create(:interview_response, interview: interview, question: question,
                          evaluation_status: :completed,
                          evaluation_data: { 'final_score' => 30, 'passed' => false })

        decision = judge.judge_after_response(response)
        expect(decision).not_to be_rejected
      end

      it 'オプション質問の不合格ではリジェクトしない' do
        question = situation.questions.first
        question.update!(required: false)

        response = create(:interview_response, interview: interview, question: question,
                          evaluation_status: :completed,
                          evaluation_data: { 'final_score' => 30, 'passed' => false })

        decision = judge.judge_after_response(response)
        expect(decision).not_to be_rejected
      end
    end

    context '連続不合格チェック' do
      before do
        situation.update!(max_consecutive_fails: 2, reject_on_required_fail: false)
      end

      it '連続不合格が上限に達した場合はリジェクトする' do
        q1, q2 = situation.questions.first(2)

        create(:interview_response, interview: interview, question: q1,
               evaluation_status: :completed,
               evaluation_data: { 'final_score' => 30, 'passed' => false })
        create(:interview_response, interview: interview, question: q2,
               evaluation_status: :completed,
               evaluation_data: { 'final_score' => 20, 'passed' => false })

        # 3問目の回答（実際はjudge_after_responseは最新の回答後に呼ばれるが、
        # 連続不合格カウントは既存のcompletedな回答から計算する）
        last_response = interview.interview_responses.last
        decision = judge.judge_after_response(last_response)

        expect(decision).to be_rejected
        expect(decision.details[:reason_code]).to eq('consecutive_fails')
      end

      it '合格が間に入れば連続カウントはリセットされる' do
        q1, q2, q3 = situation.questions

        create(:interview_response, interview: interview, question: q1,
               evaluation_status: :completed,
               evaluation_data: { 'final_score' => 30, 'passed' => false })
        create(:interview_response, interview: interview, question: q2,
               evaluation_status: :completed,
               evaluation_data: { 'final_score' => 90, 'passed' => true })
        last_response = create(:interview_response, interview: interview, question: q3,
                               evaluation_status: :completed,
                               evaluation_data: { 'final_score' => 30, 'passed' => false })

        decision = judge.judge_after_response(last_response)
        expect(decision).not_to be_rejected
      end

      it 'max_consecutive_failsが0の場合はチェックしない' do
        situation.update!(max_consecutive_fails: 0)
        q1 = situation.questions.first

        response = create(:interview_response, interview: interview, question: q1,
                          evaluation_status: :completed,
                          evaluation_data: { 'final_score' => 10, 'passed' => false })

        decision = judge.judge_after_response(response)
        expect(decision).not_to be_rejected
      end
    end
  end

  describe '#judge_on_completion' do
    context 'auto_rejectが無効' do
      it 'リジェクトしない' do
        situation.update!(auto_reject_enabled: false)
        responses = situation.questions.map do |q|
          create(:interview_response, :failed_evaluation, interview: interview, question: q)
        end

        decision = judge.judge_on_completion(responses)
        expect(decision).not_to be_rejected
      end
    end

    it '平均スコアが合格基準未満の場合はリジェクトする' do
      responses = situation.questions.map do |q|
        create(:interview_response, interview: interview, question: q,
               evaluation_status: :completed,
               evaluation_data: { 'final_score' => 50, 'passed' => false })
      end

      decision = judge.judge_on_completion(responses)
      expect(decision).to be_rejected
      expect(decision.details[:reason_code]).to eq('below_passing_score')
    end

    it '平均スコアが合格基準以上の場合はリジェクトしない' do
      responses = situation.questions.map do |q|
        create(:interview_response, interview: interview, question: q,
               evaluation_status: :completed,
               evaluation_data: { 'final_score' => 85, 'passed' => true })
      end

      decision = judge.judge_on_completion(responses)
      expect(decision).not_to be_rejected
    end

    it 'スコアが空の場合はリジェクトしない' do
      responses = situation.questions.map do |q|
        create(:interview_response, interview: interview, question: q,
               evaluation_status: :pending)
      end

      decision = judge.judge_on_completion(responses)
      expect(decision).not_to be_rejected
    end
  end

  describe '#apply_rejection!' do
    it 'リジェクト決定を面接に適用する' do
      decision = InterviewEngine::RejectJudge::RejectDecision.new(
        rejected: true,
        reason: 'スコア不足',
        details: { reason_code: 'below_passing_score' }
      )

      judge.apply_rejection!(decision)

      interview.reload
      expect(interview).to be_failed
      expect(interview.rejection_reason).to eq('スコア不足')
      expect(interview.rejected_at).to be_present
      expect(interview.interview_result).to be_present
      expect(interview.interview_result).to be_failed
    end

    it 'リジェクトでない決定は何もしない' do
      decision = InterviewEngine::RejectJudge::RejectDecision.new(
        rejected: false, reason: nil, details: nil
      )

      judge.apply_rejection!(decision)

      interview.reload
      expect(interview).to be_in_progress
    end

    it 'in_progressでない面接には適用しない' do
      interview.complete!
      decision = InterviewEngine::RejectJudge::RejectDecision.new(
        rejected: true,
        reason: 'スコア不足',
        details: { reason_code: 'test' }
      )

      judge.apply_rejection!(decision)

      interview.reload
      expect(interview.rejection_reason).to be_nil
    end
  end

  describe 'RejectDecision' do
    it 'rejected?がrejectedフラグを返す' do
      rejected = described_class::RejectDecision.new(rejected: true, reason: 'test', details: {})
      not_rejected = described_class::RejectDecision.new(rejected: false, reason: nil, details: nil)

      expect(rejected).to be_rejected
      expect(not_rejected).not_to be_rejected
    end
  end
end
