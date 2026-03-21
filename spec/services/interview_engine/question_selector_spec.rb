require 'rails_helper'

RSpec.describe InterviewEngine::QuestionSelector do
  let(:client) { create(:client) }
  let(:situation) { create(:situation, client: client) }
  let!(:q1) { create(:question, situation: situation, order: 1, question_text: '質問1') }
  let!(:q2) { create(:question, situation: situation, order: 2, question_text: '質問2') }
  let!(:q3) { create(:question, situation: situation, order: 3, question_text: '質問3') }
  let(:user) { create(:user) }
  let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }
  let(:selector) { described_class.new(interview) }

  describe '#get_next_question' do
    it '未回答の最初の質問を返す' do
      question = selector.get_next_question
      expect(question).to eq(q1)
    end

    it '1問目を回答済みの場合は2問目を返す' do
      create(:interview_response, interview: interview, question: q1)

      question = selector.get_next_question
      expect(question).to eq(q2)
    end

    it 'order順に返す' do
      create(:interview_response, interview: interview, question: q1)
      create(:interview_response, interview: interview, question: q2)

      question = selector.get_next_question
      expect(question).to eq(q3)
    end

    it '全問回答済みの場合はエラーを発生する' do
      situation.questions.each do |q|
        create(:interview_response, interview: interview, question: q)
      end

      expect {
        selector.get_next_question
      }.to raise_error(RuntimeError, /All questions answered/)
    end
  end

  describe '#should_continue_interview?' do
    it '未回答の質問がある場合はtrueを返す' do
      expect(selector.should_continue_interview?).to be true
    end

    it '全問回答済みの場合はfalseを返す' do
      situation.questions.each do |q|
        create(:interview_response, interview: interview, question: q)
      end

      expect(selector.should_continue_interview?).to be false
    end
  end

  describe '#get_question_text' do
    it '質問テキストを含むハッシュを返す' do
      result = selector.get_question_text(q1)

      expect(result[:question_id]).to eq(q1.id)
      expect(result[:question_text]).to eq('質問1')
      expect(result[:question_type]).to eq('descriptive')
      expect(result[:order]).to eq(1)
      expect(result[:required]).to be true
    end

    it '選択式問題ではoptionsを含む' do
      mc_q = create(:question, :multiple_choice, situation: situation, order: 4)
      result = selector.get_question_text(mc_q)

      expect(result[:options]).to be_present
      expect(result[:options]['choices']).to be_an(Array)
    end
  end

  describe '分岐ルール' do
    context 'selected_option条件' do
      let!(:branching_q) do
        create(:question, situation: situation, order: 4,
               branching_rules: {
                 conditions: [
                   { type: 'selected_option', source_question_order: 1, value: '選択肢A', action: 'include' }
                 ],
                 default_action: 'exclude'
               }.to_json)
      end

      it '条件に一致する場合は質問を含める' do
        create(:interview_response, interview: interview, question: q1,
               audio_transcript: '選択肢A')
        create(:interview_response, interview: interview, question: q2)
        create(:interview_response, interview: interview, question: q3)

        question = selector.get_next_question
        expect(question).to eq(branching_q)
      end

      it '条件に一致しない場合は質問を除外する' do
        create(:interview_response, interview: interview, question: q1,
               audio_transcript: '選択肢B')
        create(:interview_response, interview: interview, question: q2)
        create(:interview_response, interview: interview, question: q3)

        expect(selector.should_continue_interview?).to be false
      end
    end

    context 'score_above条件' do
      let!(:branching_q) do
        create(:question, situation: situation, order: 4,
               branching_rules: {
                 conditions: [
                   { type: 'score_above', source_question_order: 1, value: 80, action: 'include' }
                 ],
                 default_action: 'exclude'
               }.to_json)
      end

      it 'スコアが基準以上の場合は質問を含める' do
        create(:interview_response, :evaluated, interview: interview, question: q1,
               evaluation_data: { 'final_score' => 85, 'passed' => true })
        create(:interview_response, interview: interview, question: q2)
        create(:interview_response, interview: interview, question: q3)

        question = selector.get_next_question
        expect(question).to eq(branching_q)
      end

      it 'スコアが基準未満の場合は質問を除外する' do
        create(:interview_response, :evaluated, interview: interview, question: q1,
               evaluation_data: { 'final_score' => 50, 'passed' => false })
        create(:interview_response, interview: interview, question: q2)
        create(:interview_response, interview: interview, question: q3)

        expect(selector.should_continue_interview?).to be false
      end
    end

    context 'score_below条件' do
      let!(:branching_q) do
        create(:question, situation: situation, order: 4,
               branching_rules: {
                 conditions: [
                   { type: 'score_below', source_question_order: 1, value: 50, action: 'include' }
                 ],
                 default_action: 'exclude'
               }.to_json)
      end

      it 'スコアが基準未満の場合は質問を含める' do
        create(:interview_response, :evaluated, interview: interview, question: q1,
               evaluation_data: { 'final_score' => 30, 'passed' => false })
        create(:interview_response, interview: interview, question: q2)
        create(:interview_response, interview: interview, question: q3)

        question = selector.get_next_question
        expect(question).to eq(branching_q)
      end
    end

    context 'answered条件' do
      let!(:branching_q) do
        create(:question, situation: situation, order: 4,
               branching_rules: {
                 conditions: [
                   { type: 'answered', source_question_order: 1, action: 'include' }
                 ],
                 default_action: 'exclude'
               }.to_json)
      end

      it 'ソース質問が回答済みの場合は質問を含める' do
        create(:interview_response, interview: interview, question: q1)
        create(:interview_response, interview: interview, question: q2)
        create(:interview_response, interview: interview, question: q3)

        question = selector.get_next_question
        expect(question).to eq(branching_q)
      end

      it 'ソース質問が未回答の場合は質問を除外する' do
        # q1は未回答だがq2,q3は回答済み
        create(:interview_response, interview: interview, question: q2)
        create(:interview_response, interview: interview, question: q3)

        # q1は未回答なので最初にq1が返される（branching_qは除外）
        question = selector.get_next_question
        expect(question).to eq(q1)
      end
    end

    context '分岐ルールなしの質問' do
      it '常に含まれる' do
        question = selector.get_next_question
        expect(question).to eq(q1)
        expect(q1.has_branching_rules?).to be false
      end
    end
  end
end
