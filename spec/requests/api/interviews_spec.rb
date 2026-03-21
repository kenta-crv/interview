require 'rails_helper'

RSpec.describe 'Api::Interviews', type: :request do
  let(:client) { create(:client) }
  let(:situation) { create(:situation, :with_questions, client: client) }
  let!(:user) { create(:user) }

  before do
    # テストモードを有効化してDevise認証をバイパス
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('AI_INTERVIEW_TEST_MODE').and_return('true')
    allow(ENV).to receive(:fetch).and_call_original
  end

  # ============================================================
  # POST /api/interviews/start
  # ============================================================
  describe 'POST /api/interviews/start' do
    it 'starts a new interview' do
      post '/api/interviews/start', params: {
        situation_id: situation.id,
        language: 'ja'
      }, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['interview_id']).to be_present
      expect(body['access_token']).to be_present
      expect(body['status']).to eq('in_progress')
      expect(body['total_questions']).to eq(3)
    end

    it 'returns error for non-existent situation' do
      post '/api/interviews/start', params: {
        situation_id: 99999
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns remaining_seconds and session_timeout_minutes' do
      post '/api/interviews/start', params: {
        situation_id: situation.id
      }, as: :json

      body = JSON.parse(response.body)
      expect(body['session_timeout_minutes']).to eq(situation.session_timeout_minutes)
      expect(body['remaining_seconds']).to be_present
    end

    it 'returns existing in_progress interview on duplicate start' do
      post '/api/interviews/start', params: { situation_id: situation.id }, as: :json
      first_id = JSON.parse(response.body)['interview_id']

      post '/api/interviews/start', params: { situation_id: situation.id }, as: :json
      second_id = JSON.parse(response.body)['interview_id']

      expect(second_id).to eq(first_id)
    end
  end

  # ============================================================
  # POST /api/interviews/start_by_token
  # ============================================================
  describe 'POST /api/interviews/start_by_token' do
    it 'starts interview by valid access_token' do
      interview = create(:interview, user: user, situation: situation)

      post '/api/interviews/start_by_token', params: {
        access_token: interview.access_token
      }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['interview_id']).to eq(interview.id)
      expect(body['status']).to eq('in_progress')
    end

    it 'returns error without access_token' do
      post '/api/interviews/start_by_token', params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error for invalid access_token' do
      post '/api/interviews/start_by_token', params: {
        access_token: 'invalid_token'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 410 for timed-out interview' do
      interview = create(:interview, :timed_out, user: user, situation: situation)

      post '/api/interviews/start_by_token', params: {
        access_token: interview.access_token
      }, as: :json

      expect(response).to have_http_status(:gone)
    end

    it 'returns 403 for abandoned interview with max resumes reached' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      interview.update_column(:resume_count, situation.max_resume_count)

      post '/api/interviews/start_by_token', params: {
        access_token: interview.access_token
      }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================
  # GET /api/interviews/:id/status
  # ============================================================
  describe 'GET /api/interviews/:id/status' do
    let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }

    it 'returns interview status' do
      get "/api/interviews/#{interview.id}/status",
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['state']).to be_present
      expect(body['state']['status']).to eq('in_progress')
      expect(body['state']['total_questions']).to eq(3)
    end

    it 'includes rejection info in status' do
      interview.update!(rejection_reason: 'スコア不足', rejected_at: Time.current)

      get "/api/interviews/#{interview.id}/status",
        headers: { 'X-Interview-Token' => interview.access_token }

      body = JSON.parse(response.body)
      expect(body['state']['rejected']).to be true
      expect(body['state']['rejection_reason']).to eq('スコア不足')
    end

    it 'returns 404 for non-existent interview' do
      get '/api/interviews/99999/status',
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:not_found)
    end
  end

  # ============================================================
  # GET /api/interviews/:id/next_question
  # ============================================================
  describe 'GET /api/interviews/:id/next_question' do
    let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }

    it 'returns 404 for non-existent interview' do
      get '/api/interviews/99999/next_question',
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns next question with audio data' do
      # TTSをモックして音声生成をスキップ
      allow_any_instance_of(InterviewEngine::TTSClient).to receive(:speak).and_return(nil)

      get "/api/interviews/#{interview.id}/next_question",
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['question']).to be_present
      expect(body['question']['question_id']).to be_present
      expect(body['question']['question_text']).to be_present
      expect(body['remaining_seconds']).to be_present
    end

    it 'returns interview_complete when all questions answered' do
      allow_any_instance_of(InterviewEngine::TTSClient).to receive(:speak).and_return(nil)

      situation.questions.each do |q|
        create(:interview_response, interview: interview, question: q)
      end

      get "/api/interviews/#{interview.id}/next_question",
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['interview_complete']).to be true
    end

    it 'returns error for not-in-progress interview' do
      interview = create(:interview, user: user, situation: situation)

      get "/api/interviews/#{interview.id}/next_question",
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 410 for timed-out interview' do
      interview.update_column(:last_activity_at, 2.hours.ago)

      get "/api/interviews/#{interview.id}/next_question",
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:gone)
    end
  end

  # ============================================================
  # POST /api/interviews/:id/submit_answer
  # ============================================================
  describe 'POST /api/interviews/:id/submit_answer' do
    let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }
    let(:question) { situation.questions.first }

    it 'returns error without question_id' do
      post "/api/interviews/#{interview.id}/submit_answer",
        params: {},
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['success']).to be false
    end

    it 'submits text answer successfully' do
      post "/api/interviews/#{interview.id}/submit_answer",
        params: {
          question_id: question.id,
          text_answer: 'テスト回答です'
        },
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['response_id']).to be_present
    end

    it 'returns error for non-existent question' do
      post "/api/interviews/#{interview.id}/submit_answer",
        params: {
          question_id: 99999,
          text_answer: 'テスト'
        },
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'prevents duplicate answer for same question' do
      create(:interview_response, interview: interview, question: question)

      post "/api/interviews/#{interview.id}/submit_answer",
        params: {
          question_id: question.id,
          text_answer: '二重回答'
        },
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:conflict)
    end

    it 'returns error without answer input' do
      post "/api/interviews/#{interview.id}/submit_answer",
        params: { question_id: question.id },
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it 'enqueues evaluation job after submission' do
      expect {
        post "/api/interviews/#{interview.id}/submit_answer",
          params: {
            question_id: question.id,
            text_answer: 'テスト回答'
          },
          headers: { 'X-Interview-Token' => interview.access_token },
          as: :json
      }.to have_enqueued_job(EvaluateInterviewResponseJob)
    end

    it 'accepts selected_option parameter' do
      mc_question = create(:question, :multiple_choice, situation: situation,
                           options: { 'choices' => %w[A B C], 'correct' => 'A' })

      post "/api/interviews/#{interview.id}/submit_answer",
        params: {
          question_id: mc_question.id,
          selected_option: 'A'
        },
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:created)
    end

    it 'returns 410 for timed-out interview' do
      interview.update_column(:last_activity_at, 2.hours.ago)

      post "/api/interviews/#{interview.id}/submit_answer",
        params: {
          question_id: question.id,
          text_answer: 'テスト'
        },
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:gone)
    end
  end

  # ============================================================
  # POST /api/interviews/:id/complete
  # ============================================================
  describe 'POST /api/interviews/:id/complete' do
    it 'returns error for non-in_progress interview' do
      interview = create(:interview, user: user, situation: situation)

      post "/api/interviews/#{interview.id}/complete",
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('Interview not in progress')
    end

    it 'completes interview with evaluated responses' do
      interview = create(:interview, :in_progress, user: user, situation: situation)

      situation.questions.each do |q|
        create(:interview_response, :evaluated, interview: interview, question: q)
      end

      # LLMサマリーをモック
      llm_mock = instance_double(InterviewEngine::LLMClient)
      allow(InterviewEngine::LLMClient).to receive(:new).and_return(llm_mock)
      allow(llm_mock).to receive(:summarize_interview).and_return({
        summary: '要約', strengths: ['強み'], weaknesses: ['弱み'], recommendation: '推奨'
      })

      post "/api/interviews/#{interview.id}/complete",
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['result']['final_status']).to be_present
      expect(body['result']['average_score']).to be_present
    end

    it 'returns error when pending responses exist' do
      interview = create(:interview, :in_progress, user: user, situation: situation)
      question = situation.questions.first
      create(:interview_response, interview: interview, question: question, evaluation_status: :pending)

      post "/api/interviews/#{interview.id}/complete",
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ============================================================
  # POST /api/interviews/:id/resume
  # ============================================================
  describe 'POST /api/interviews/:id/resume' do
    it 'resumes an abandoned interview' do
      interview = create(:interview, :abandoned, user: user, situation: situation)

      post "/api/interviews/#{interview.id}/resume",
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['status']).to eq('in_progress')
      expect(body['resume_count']).to eq(1)
    end

    it 'returns error for non-resumable interview' do
      interview = create(:interview, :completed, user: user, situation: situation)

      post "/api/interviews/#{interview.id}/resume",
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns error when max resume count reached' do
      interview = create(:interview, :abandoned, user: user, situation: situation)
      interview.update_column(:resume_count, situation.max_resume_count)

      post "/api/interviews/#{interview.id}/resume",
        headers: { 'X-Interview-Token' => interview.access_token },
        as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================
  # Authentication
  # ============================================================
  describe 'authentication' do
    let(:interview) { create(:interview, :in_progress, user: user, situation: situation) }

    it 'rejects invalid token' do
      # テストモードを無効化して認証を検証
      allow(ENV).to receive(:[]).with('AI_INTERVIEW_TEST_MODE').and_return(nil)

      get "/api/interviews/#{interview.id}/status",
        headers: { 'X-Interview-Token' => 'invalid_token' }

      # トークン不一致でDevise認証にフォールバック → 302(リダイレクト)または401
      expect(response.status).to be_in([302, 401, 403])
    end

    it 'accepts valid X-Interview-Token header' do
      allow(ENV).to receive(:[]).with('AI_INTERVIEW_TEST_MODE').and_return(nil)

      get "/api/interviews/#{interview.id}/status",
        headers: { 'X-Interview-Token' => interview.access_token }

      expect(response).to have_http_status(:ok)
    end

    it 'accepts access_token as parameter' do
      allow(ENV).to receive(:[]).with('AI_INTERVIEW_TEST_MODE').and_return(nil)

      get "/api/interviews/#{interview.id}/status",
        params: { access_token: interview.access_token }

      expect(response).to have_http_status(:ok)
    end
  end

  # ============================================================
  # Content-Type validation
  # ============================================================
  describe 'Content-Type validation' do
    it 'rejects unsupported content type' do
      post '/api/interviews/start',
        params: 'text data',
        headers: { 'Content-Type' => 'text/plain' }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it 'accepts application/json' do
      post '/api/interviews/start',
        params: { situation_id: situation.id }.to_json,
        headers: { 'Content-Type' => 'application/json' }

      # Created or error, but not 415
      expect(response.status).not_to eq(415)
    end
  end
end
