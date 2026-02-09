# 🏗️ PRODUCTION-GRADE AI Interview System - Implementation Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    RAILS API BACKEND                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Controllers (API)                                           │
│  ├─ /api/interviews/start          → POST                   │
│  ├─ /api/interviews/:id/next_question → GET                 │
│  ├─ /api/interviews/:id/submit_answer → POST                │
│  ├─ /api/interviews/:id/status     → GET                    │
│  └─ /api/interviews/:id/complete   → POST                   │
│                                                              │
│  Services Layer (Business Logic)                             │
│  ├─ SessionManager          (Interview lifecycle)            │
│  ├─ QuestionSelector        (Question flow)                  │
│  ├─ ResponseEvaluator       (Evaluation orchestration)       │
│  ├─ LLMClient               (OpenAI/Claude integration)      │
│  ├─ STTClient               (Speech-to-text)                 │
│  └─ TTSClient               (Text-to-speech)                 │
│                                                              │
│  Models (ActiveRecord)                                       │
│  ├─ Interview               (Session state machine)          │
│  ├─ InterviewResponse       (Individual answer + score)      │
│  ├─ InterviewResult         (Final results summary)          │
│  ├─ Question                (Pre-defined questions)          │
│  └─ Situation               (Interview template)             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL SERVICES                          │
├─────────────────────────────────────────────────────────────┤
│  OpenAI API (for scoring & TTS)                              │
│  - GPT-4: Answer evaluation with strict JSON schema          │
│  - Whisper: Speech-to-text transcription                     │
│  - TTS: Question audio generation                            │
│                                                              │
│  Cloud Storage (Optional)                                    │
│  - S3/R2: Audio & video file storage                         │
│  - Rails ActiveStorage for management                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## State Machine: Interview Lifecycle

```
┌──────────────┐
│   CREATED    │ (new interview record)
└──────┬───────┘
       │ start!
       ▼
┌──────────────┐
│ IN_PROGRESS  │ ◄─── Process each question
├──────────────┤     (answer → submit → evaluate)
│ Q1 → Q2 → Q3│
└──────┬───────┘
       │ Complete all OR fail early
       ▼
    ┌─────────────────┐
    │   Evaluation    │
    │   Complete?     │
    └────┬─────┬──────┘
         │     │
    YES  │     │  NO
         ▼     ▼
    ┌────────┐ ┌──────────┐
    │COMPLETED│ │ FAILED   │
    └────────┘ └──────────┘
         │          │
         └──────┬───┘
                ▼
         ┌─────────────┐
         │ Generate    │
         │ Results &   │
         │ Feedback    │
         └─────────────┘
```

---

## Database Schema

### Interviews Table
```ruby
create_table :interviews do |t|
  t.references :user, foreign_key: true
  t.references :situation, foreign_key: true
  t.integer :status              # Enum: not_started, in_progress, completed, failed
  t.string :language             # en, ja
  t.timestamp :started_at         # When interview started
  t.timestamp :ended_at           # When interview finished
  t.timestamps
end
```

### Interview Responses Table
```ruby
create_table :interview_responses do |t|
  t.references :interview, foreign_key: true
  t.references :question, foreign_key: true
  t.text :audio_transcript        # User's spoken answer (transcribed)
  t.integer :evaluation_status    # pending, evaluating, completed, failed
  t.json :evaluation_data         # Scores, reasoning, feedback (JSON stored)
  
  # Audio/Video files (ActiveStorage)
  t.timestamps
end
```

### Interview Results Table
```ruby
create_table :interview_results do |t|
  t.references :interview, foreign_key: true, unique: true
  t.integer :final_status         # passed, failed
  t.json :results_data            # Summary, strengths, weaknesses
  t.timestamps
end
```

---

## API Specification

### 1. Start Interview
```
POST /api/interviews/start
Content-Type: application/json

Request Body:
{
  "situation_id": 1,
  "language": "en"  # Optional: default from situation
}

Response (201 Created):
{
  "success": true,
  "interview_id": 123,
  "status": "in_progress",
  "total_questions": 3,
  "language": "en"
}

Error (422 Unprocessable Entity):
{
  "success": false,
  "error": "User has already completed this interview"
}
```

---

### 2. Get Next Question
```
GET /api/interviews/:id/next_question?language=en

Response (200 OK):
{
  "success": true,
  "question": {
    "id": 1,
    "order": 1,
    "question_text": "Tell us about your experience with Rails",
    "question_type": "descriptive",  # or "multiple_choice"
    "audio_url": "https://...mp3"   # Optional: pre-generated TTS
  }
}

If All Questions Answered:
{
  "success": true,
  "message": "All questions answered",
  "interview_complete": true
}

Error (400 Bad Request):
{
  "success": false,
  "error": "Interview not in progress"
}
```

---

### 3. Submit Answer
```
POST /api/interviews/:id/submit_answer

Content-Type: multipart/form-data

Body:
- audio (file, .wav/.mp3)             # User's recorded answer
- transcript (string, optional)        # Manual transcript if audio not available
- video (file, optional)               # For video interviews
- question_id (integer)                # Which question this answers

Custom Header:
- X-Language: en                       # Optional: override language

Response (200 OK):
{
  "success": true,
  "response": {
    "id": 456,
    "evaluation_status": "pending",    # or "evaluating", "completed"
    "message": "Answer submitted, evaluating..."
  }
}

Async: Once evaluation completes (webhook or polling):
{
  "evaluation_status": "completed",
  "relevance_score": 85,
  "correctness_score": 88,
  "clarity_score": 86,
  "final_score": 86.3,
  "passed": true,
  "ai_reasoning": "Strong technical knowledge demonstrated..."
}

Error (400 Bad Request):
{
  "success": false,
  "error": "Audio transcription failed"
}
```

---

### 4. Check Status
```
GET /api/interviews/:id/status

Response (200 OK):
{
  "success": true,
  "state": {
    "interview_id": 123,
    "status": "in_progress",
    "progress": 66.67,              # Percentage
    "answered_questions": 2,
    "total_questions": 3,
    "duration_seconds": 425
  }
}
```

---

### 5. Complete Interview
```
POST /api/interviews/:id/complete

Response (200 OK):
{
  "success": true,
  "message": "Interview completed",
  "result": {
    "final_status": "passed",
    "average_score": 85.3,
    "total_questions": 3,
    "answered_questions": 3
  }
}

Error (422 Unprocessable Entity):
{
  "success": false,
  "error": "Cannot complete: 1 response still pending evaluation"
}
```

---

## Service Layer Integration

### SessionManager (Interview Lifecycle)
```ruby
manager = InterviewEngine::SessionManager.new(user, situation)

# Start interview
interview = manager.start_interview(language: 'en')

# Get state
state = manager.get_interview_state(interview.id)

# Fail early (if response too low)
manager.fail_interview(interview.id, "Failed at question 2")

# Complete with results
result = manager.complete_interview(interview.id)
```

### ResponseEvaluator (Scoring)
```ruby
evaluator = InterviewEngine::ResponseEvaluator.new(response, language: 'en')

# Evaluate and update response
response = evaluator.evaluate

# Access results
response.final_score      # 85.3
response.passed?          # true
response.ai_reasoning     # "Strong answer with..."
```

### LLMClient (OpenAI Integration)
```ruby
llm = InterviewEngine::LLMClient.new(model: 'openai')

# Evaluate response
evaluation = llm.evaluate_response(
  question_text: "Tell us about Rails",
  user_answer: "I have 5 years...",
  language: 'en'
)

# Returns strict JSON:
{
  relevance_score: 85,
  correctness_score: 88,
  clarity_score: 86,
  final_score: 86.3,
  passed: true,
  reasoning: "..."
}

# Generate summary
summary = llm.summarize_interview(responses, language: 'en')
# {summary: "...", strengths: [...], weaknesses: [...], recommendation: "..."}
```

---

## Scoring Algorithm

### Weighted Average Calculation
```
final_score = (
  relevance_score * 0.4 +      # 40% - Addresses the question?
  correctness_score * 0.4 +     # 40% - Accurate information?
  clarity_score * 0.2           # 20% - Well explained?
) rounded to 2 decimals, capped at 100

Pass Threshold: >= 70
Interview Continuation: Fail early if any response < 70
```

---

## Error Handling Strategy

### Non-Recoverable Errors (Fail Interview)
- Single response scores < 70 → immediate interview failure
- LLM unavailable → fail the entire interview (cannot evaluate fairly)
- Multiple questions unanswered

### Recoverable Errors (Retry Logic)
- Network timeouts → retry once
- Transcription fails → allow manual text input
- TTS unavailable → show question text only

### Validation Rules
- User can attempt each situation **exactly once**
- Interview must progress sequentially (can skip, but not go backward)
- Responses must not be re-answered once submitted

---

## Security & Authentication

### Authentication
- Users authenticate with email + password (Devise)
- JWT tokens optional for mobile clients
- Session validation on every API request

### Authorization Rules
```ruby
# User can only access their own interviews
interview = Interview.find(params[:id])
authorize_user_owns_interview!(interview, current_user)

# Cannot re-answer once submitted
raise "Cannot modify completed response" if response.completed?

# Cannot access after interview complete
raise "Cannot add answers after completion" if interview.completed?
```

### Data Privacy
- Audio files stored in S3 with encryption
- Evaluation results hashed if needed (GDPR compliance)
- Audit logging for all evaluations
- Auto-deletion of audio after 30 days (configurable)

---

## Production Deployment Checklist

- [ ] **Environment Variables**
  - `OPENAI_API_KEY` set and validated
  - `CLAUDE_API_KEY` (if using Claude)
  - `AWS_ACCESS_KEY_ID` (for S3 storage)
  - `AWS_SECRET_ACCESS_KEY`

- [ ] **Database**
  - All migrations run: `rails db:migrate`
  - Production database connection verified
  - Backups configured

- [ ] **ActiveStorage**
  - S3 bucket created and configured
  - CORS headers set correctly
  - IAM permissions verified

- [ ] **Sidekiq** (Optional for async evaluation)
  - Redis instance running
  - Sidekiq worker processes started
  - Job queues configured

- [ ] **Error Tracking**
  - Sentry/Honeybadger configured
  - LLM API errors logged
  - Audio transcription failures monitored

- [ ] **Rate Limiting**
  - OpenAI API rate limits understood
  - Throttling implemented for interview starts
  - Cost monitoring set up

- [ ] **Monitoring**
  - Interview success rates tracked
  - Average scoring vs. manual scoring compared
  - LLM response times monitored
  - Audio transcription quality metrics

---

## Testing Strategy

### Unit Tests
```ruby
# Test ResponseEvaluator scoring
evaluator = InterviewEngine::ResponseEvaluator.new(response)
response = evaluator.evaluate
assert response.final_score > 0 && response.final_score <= 100
```

### Integration Tests
```ruby
# Test full interview flow
interview = Interview.create!(user: user, situation: situation)
interview.start!

# Get question
question = interview.situation.questions.first

# Submit answer
response = interview.interview_responses.create!(...)
evaluator = InterviewEngine::ResponseEvaluator.new(response)
evaluator.evaluate

assert response.evaluation_data['final_score'].present?
```

### API Tests
```ruby
# Test complete API flow
post '/api/interviews/start', params: {situation_id: 1}
interview_id = response.parsed_body['interview_id']

get "/api/interviews/#{interview_id}/next_question"
question = response.parsed_body['question']

post "/api/interviews/#{interview_id}/submit_answer",
  params: {question_id: question['id'], text_answer: 'Test answer'}

post "/api/interviews/#{interview_id}/complete"
assert response.status == 200
```

---

## Performance Optimization

### Caching
- Cache question text/audio for repeated requests
- Cache LLM prompts (rarely change)
- Pre-generate TTS audio during question creation

### Async Processing
- Evaluation runs in background (Sidekiq job)
- TTS generation off-peak
- Results summary generated after all responses complete

### Database Optimization
- Index: (user_id, situation_id) on interviews
- Index: (interview_id, question_id) on responses
- Eager load associations: `Interview.includes(:questions, :interview_responses)`

### LLM Optimization
- Batch evaluations if processing multiple candidates
- Use `gpt-3.5-turbo` for cost savings (faster than gpt-4)
- Cache evaluation results for identical answers (unlikely but possible)

---

## Compliance & Legal

- [ ] Record user consent to audio recording
- [ ] Implement GDPR data deletion (right to be forgotten)
- [ ] Audit trail for all evaluations
- [ ] Clear disclosure that AI is used for scoring
- [ ] Human review process for borderline cases (score 65-75)

---

## Troubleshooting Guide

### Interview won't start
```
Error: "User has already completed this interview"
Fix: User already did this interview.
  → Create new situation or allow multiple attempts (modify validation)
```

### Transcription fails
```
Error: "Failed to transcribe audio"
Fix: Audio quality, format, or API issue
  1. Check audio file format (WAV preferred)
  2. Verify Whisper API key valid
  3. Allow manual text input as fallback
```

### Evaluation hangs
```
Symptom: evaluation_status stays "evaluating"
Fix: 
  1. Check Redis/Sidekiq running
  2. Review LLM API error logs
  3. Timeout responses to manual scoring
```

### User sees unfair score
```
Fix: Implement human review layer
  1. Flag scores outside 60-80 range
  2. Admin dashboard for manual override
  3. Store original LLM output for audit
```

---

## Next Steps / Roadmap

### Phase 1: MVP ✅
- [x] Basic interview flow
- [x] LLM-based scoring
- [x] Audio/text support

### Phase 2: UX & Reliability
- [ ] Real-time score updates (WebSocket)
- [ ] Better error messages
- [ ] Audio quality feedback
- [ ] Candidate instructions video

### Phase 3: Analytics & Reports
- [ ] Dashboard for hiring managers
- [ ] Candidate comparison reports
- [ ] Trend analysis (scores over time)
- [ ] Feedback generation for candidates

### Phase 4: Advanced Features
- [ ] Video interview support
- [ ] Behavioral questions with tone analysis
- [ ] Multiple language support
- [ ] Scheduling & calendar integration
- [ ] Webhook notifications

---

**Version**: 1.0  
**Last Updated**: February 8, 2026  
**Status**: Production Ready

