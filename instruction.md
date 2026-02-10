# AI Interview System – Backend Instructions (Rails)

## Overview

This document defines how to implement a **rule-based AI Interview System** inside an **existing Ruby on Rails backend**.

The system conducts structured interviews using:
- predefined questions
- AI voice output (Text-to-Speech)
- AI-based response evaluation
- strict interview rules

⚠️ Voice is included  
❌ No speaking avatar or video avatar is included

---

## System Goals

The backend must:
- conduct interviews in a controlled, deterministic way
- prevent free-form AI conversation
- evaluate applicant responses objectively
- store all interview data in the Rails database
- expose REST APIs for frontend consumption

This system is **not a chatbot**. It is an **interview engine**.

---

## Technology Stack

- Backend: **Ruby on Rails (API mode)**
- AI Model: **Claude or OpenAI**
- Speech-to-Text (STT): **Whisper or equivalent**
- Text-to-Speech (TTS): **Female voice (API-based)**
- Database: **Rails ActiveRecord**
- Authentication: **Rails token/session-based**
- Communication: **REST APIs**

---

## High-Level Flow

Frontend  
→ Rails Controller  
→ Interview Service Layer  
→ AI APIs (STT / LLM / TTS)  
→ Rails Database  

Rails is the **single source of truth**.

---

## Design Principles

- Strict rule enforcement
- No improvisation by AI
- No emotional or casual responses
- Only predefined questions allowed
- All AI outputs must be structured
- Interview must be auditable

---

## Required Rails Structure

Business logic **must NOT** live in controllers.

app/
controllers/
api/interviews_controller.rb
services/
interview_engine/
session_manager.rb
question_selector.rb
response_evaluator.rb
llm_client.rb
stt_client.rb
tts_client.rb
models/
interview.rb
interview_question.rb
interview_response.rb
interview_result.rb


---

## Interview Lifecycle

### 1. Start Interview

**Endpoint**
POST /api/interviews/start


**Rails must**
- validate applicant identity
- ensure applicant has not interviewed before
- load interview flow configuration
- create an `Interview` record
- return `interview_id`

---

### 2. Ask Question (Voice Only)

Rails must:
- select the next predefined question
- convert question text to speech (TTS)
- return the audio URL or audio bytes

**Rules**
- AI must speak only the stored question text
- No rephrasing
- No commentary

---

### 3. Receive Answer (Voice Input)

**Endpoint**
POST /api/interviews/:id/answer


Rails must:
- convert audio to text using STT
- validate transcript is not empty
- store transcript in database
- associate answer with question

---

### 4. Evaluate Response

Rails must:
- send transcript to LLM using a **strict prompt**
- evaluate relevance and correctness
- receive JSON-only output

LLM is allowed only for:
- relevance checking
- intent matching
- scoring

LLM must NEVER:
- ask questions
- talk conversationally
- generate explanations

---

### 5. Decision Logic

Rails must:
- calculate score
- determine next question
- or terminate interview early

If response is irrelevant:
- mark interview as FAILED
- stop further questions

---

### 6. Complete Interview

When interview ends:
- calculate final score
- determine PASS / FAIL
- generate summary
- store all results in DB
- expose results for admin review

---

## Interview Rules (Mandatory)

Rails must enforce:
- one interview per applicant
- no retries
- no skipped questions
- only predefined questions
- no post-interview interaction

---

## API Endpoints Summary

| Action | Endpoint |
|------|---------|
| Start interview | POST `/api/interviews/start` |
| Get next question | GET `/api/interviews/:id/next_question` |
| Submit answer | POST `/api/interviews/:id/answer` |
| Complete interview | POST `/api/interviews/:id/complete` |

---

## Prompt Control Rules

All LLM prompts must:
- be system-restricted
- enforce JSON schema
- reject conversational output
- support EN and JP languages

Invalid AI output must be retried or rejected safely.

---

## Error Handling

Rails must:
- reject duplicate interviews
- reject invalid audio
- reject malformed AI output
- return structured error responses

---

## Explicitly Excluded

Do NOT implement:
- speaking avatars
- video avatars
- free chat
- emotional analysis
- face tracking
- interview scheduling

---

## Summary

This system is a **controlled AI interviewer**, not a chatbot.

Rails manages:
- flow
- rules
- data
- decisions

AI is used only as a **tool**, never as a conversational agent.