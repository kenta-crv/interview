# Day 3 — 技術仕様・API設計書

**作成日:** 2026-03-04 | **リポジトリ:** tianzhongyoushi178/AI_Interviewer | **ブランチ:** master

---

## 目次

1. [LLM制御方針](#1-llm制御方針)
2. [外部API一覧](#2-外部api一覧)
3. [DB設計書（ER図）最終版](#3-db設計書er図最終版)
4. [内部API設計書](#4-内部api設計書)

---

# 1. LLM制御方針

## 1.1 基本原則：自由生成の排除

本システムではLLMの出力を**構造化JSON**に限定し、自由文生成によるハルシネーションリスクを排除する。

| 制御項目 | 方針 |
|---------|------|
| 出力形式 | **JSON Only** — プロンプトで `Return ONLY valid JSON` を明示 |
| Temperature | **0.3**（評価）/ 0.4（記事生成）— 低温で決定的出力を強制 |
| Max Tokens | **500**（評価・要約）— 不必要な長文出力を防止 |
| System Prompt | 役割限定 + 「Do NOT engage in conversation」等の禁止ルール |
| レスポンス検証 | JSON パース + 必須キー存在チェック + フォールバック |

## 1.2 プロンプトテンプレート設計

### A. 回答評価プロンプト（ResponseEvaluator → LLMClient）

```
用途: 個別回答のスコアリング
モデル: GPT-4（→ GPT-4o-mini に変更推奨）
Temperature: 0.3
Max Tokens: 500
```

**System Prompt:**
```
You are an interview evaluator. Return ONLY valid JSON.
```

**User Prompt テンプレート:**
```
You are a strict interview evaluator. Evaluate the candidate's response
ONLY based on the provided criteria.

{language_instruction}  ← 日本語 or English

INTERVIEW QUESTION:
"{question_text}"

CANDIDATE'S ANSWER:
"{user_answer}"

EVALUATION CRITERIA:
1. Relevance (0-100): Does the answer address the question?
2. Correctness (0-100): Is the information accurate?
3. Clarity (0-100): Is the answer clear and well-structured?

IMPORTANT RULES:
- Do NOT engage in conversation
- Do NOT ask follow-up questions
- Provide ONLY JSON output
- No explanations outside JSON
- All scores must be 0-100
- If answer is completely irrelevant, set all scores to 0

Return ONLY valid JSON in this format:
{
  "relevance_score": <0-100>,
  "correctness_score": <0-100>,
  "clarity_score": <0-100>,
  "final_score": <0-100>,
  "passed": <true|false>,
  "reasoning": "<brief explanation>"
}
```

**期待する出力スキーマ:**

| キー | 型 | 範囲 | 必須 |
|------|-----|------|------|
| relevance_score | integer | 0-100 | Yes |
| correctness_score | integer | 0-100 | Yes |
| clarity_score | integer | 0-100 | Yes |
| final_score | float | 0-100 | Yes |
| passed | boolean | true/false | Yes |
| reasoning | string | - | Yes |

### B. 面接要約プロンプト（SessionManager → LLMClient）

```
用途: 面接完了後の総合フィードバック生成
モデル: GPT-4（→ GPT-4o に変更推奨）
Temperature: 0.3
Max Tokens: 500
```

**User Prompt テンプレート:**
```
You are a strict interview summarizer. Produce a concise summary
and structured feedback.

{language_instruction}

RESPONSES (JSON):
{serialized_responses}  ← [{question, answer, score}, ...]

IMPORTANT RULES:
- Do NOT engage in conversation
- Provide ONLY JSON output
- No explanations outside JSON
- Keep summary under 5 sentences

Return ONLY valid JSON in this format:
{
  "summary": "<short summary>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "weaknesses": ["<weakness 1>", "<weakness 2>"],
  "recommendation": "<hire/no hire or next step>"
}
```

**期待する出力スキーマ:**

| キー | 型 | 必須 |
|------|-----|------|
| summary | string (5文以内) | Yes |
| strengths | string[] | Yes |
| weaknesses | string[] | Yes |
| recommendation | string | Yes |

### C. MCQ（選択式）評価 — LLM不使用

選択式問題はLLMを呼ばず、即時判定する。

```
正解一致 → 全スコア100, passed=true
不正解   → 全スコア0,   passed=false
```

## 1.3 バリデーション・フォールバック設計

### レスポンス解析フロー

```
LLMレスポンス受信
    │
    ▼
JSON全体をパース試行
    │
    ├─ 成功 → 必須キー存在チェック → 使用
    │
    └─ 失敗 → 正規表現 /\{[\s\S]*\}/ でJSON抽出
                  │
                  ├─ 抽出成功 → パース → 使用
                  │
                  └─ 抽出失敗 → デフォルトエラーレスポンス
```

### デフォルトエラーレスポンス

**評価失敗時:**
```json
{
  "relevance_score": 0,
  "correctness_score": 0,
  "clarity_score": 0,
  "final_score": 0,
  "passed": false,
  "reasoning": "Evaluation failed - please retry"
}
```

**要約失敗時:**
```json
{
  "summary": "Summary unavailable",
  "strengths": [],
  "weaknesses": [],
  "recommendation": "Review required"
}
```

## 1.4 テストモード

`AI_INTERVIEW_TEST_MODE=true` 時はLLMを呼ばず固定スコアを返却。

```json
{
  "relevance_score": 85,
  "correctness_score": 80,
  "clarity_score": 82,
  "final_score": 82.5,
  "passed": true,
  "reasoning": "Test mode evaluation"
}
```

> **要改善**: `Rails.env.production?` ガードを追加し、本番での有効化を防止する。

## 1.5 セキュリティリスクと対策

| リスク | 現状 | 対策案 |
|--------|------|--------|
| プロンプトインジェクション | ユーザー入力を直接埋め込み | 入力のサニタイズ・エスケープ処理追加 |
| JSON構造破壊 | 正規表現で最初のJSONを抽出 | 厳密なJSONパース + スキーマバリデーション |
| テストモード本番流出 | 環境変数のみで制御 | `Rails.env.production?` ガード追加 |
| API障害時の無評価 | スコア0で記録 | リトライ機構 + 管理者通知 |

---

# 2. 外部API一覧

## 2.1 API一覧サマリー

| # | API | プロバイダ | 用途 | 環境変数 | 現在のモデル | 推奨モデル |
|---|-----|----------|------|---------|------------|-----------|
| 1 | Chat Completions | OpenAI | 回答評価 | `OPENAI_API_KEY` | gpt-4 | **gpt-4o-mini** |
| 2 | Chat Completions | OpenAI | 面接要約 | `OPENAI_API_KEY` | gpt-4 | **gpt-4o** |
| 3 | Chat Completions | Anthropic | 回答評価（代替） | `CLAUDE_API_KEY` | claude-3-sonnet | claude-3.5-haiku |
| 4 | Audio Transcriptions | OpenAI | 音声→テキスト | `OPENAI_API_KEY` | whisper-1 | 現状維持 |
| 5 | Audio Speech | OpenAI | テキスト→音声 | `OPENAI_API_KEY` | tts-1 | 現状維持 |
| 6 | Chat Completions | OpenAI | 記事本文生成 | `GPT_API_KEY` | gpt-4o-mini | 現状維持 |
| 7 | Generate Content | Google | 記事メタ生成 | `GEMINI_API_KEY` | gemini-2.0-flash | 現状維持 |
| 8 | ffmpeg | ローカル | 動画→音声抽出 | - | - | 現状維持 |

## 2.2 各API詳細仕様

### API-1: 回答評価（OpenAI Chat Completions）

```
エンドポイント: https://api.openai.com/v1/chat/completions
メソッド:       POST
認証:           Authorization: Bearer {OPENAI_API_KEY}
Content-Type:   application/json
```

**リクエスト:**
```json
{
  "model": "gpt-4",
  "messages": [
    {"role": "system", "content": "You are an interview evaluator. Return ONLY valid JSON."},
    {"role": "user", "content": "{evaluation_prompt}"}
  ],
  "temperature": 0.3,
  "max_tokens": 500
}
```

**レスポンス（抽出後）:**
```json
{
  "relevance_score": 85,
  "correctness_score": 80,
  "clarity_score": 90,
  "final_score": 84.0,
  "passed": true,
  "reasoning": "回答は質問に的確に対応している"
}
```

**エラーハンドリング:**
- HTTPエラー → ログ記録 + デフォルトエラーレスポンス返却
- JSONパースエラー → 正規表現でJSON抽出を試行 → 失敗時デフォルト

**コスト（現在）:** $30/1M入力 + $60/1M出力
**コスト（推奨: gpt-4o-mini）:** $0.15/1M入力 + $0.60/1M出力

---

### API-2: 面接要約（OpenAI Chat Completions）

API-1と同一エンドポイント。プロンプトが要約用に変わる。

**コスト推奨: gpt-4o**（要約は品質重視）: $2.50/1M入力 + $10/1M出力

---

### API-3: 回答評価・代替（Anthropic Messages）

```
エンドポイント: https://api.anthropic.com/v1/messages
メソッド:       POST
認証:           x-api-key: {CLAUDE_API_KEY}
ヘッダー:       anthropic-version: 2023-06-01
Content-Type:   application/json
```

**リクエスト:**
```json
{
  "model": "claude-3-sonnet-20240229",
  "max_tokens": 500,
  "messages": [
    {"role": "user", "content": "{evaluation_prompt}"}
  ]
}
```

> **注意**: temperature未指定（デフォルト=1.0）→ **0.3に設定推奨**

---

### API-4: 音声認識（OpenAI Whisper）

```
エンドポイント: https://api.openai.com/v1/audio/transcriptions
メソッド:       POST (multipart/form-data)
認証:           Authorization: Bearer {OPENAI_API_KEY}
```

**リクエストパラメータ:**

| パラメータ | 値 |
|-----------|-----|
| file | 音声ファイル (binary) |
| model | whisper-1 |
| language | ja / en |

**レスポンス:**
```json
{
  "text": "文字起こしされたテキスト"
}
```

**コスト:** $0.006/分

**対応フォーマット:** mp3, wav, m4a, webm, mp4

---

### API-5: 音声合成（OpenAI TTS）

```
エンドポイント: https://api.openai.com/v1/audio/speech
メソッド:       POST
認証:           Authorization: Bearer {OPENAI_API_KEY}
Content-Type:   application/json
```

**リクエスト:**
```json
{
  "model": "tts-1",
  "input": "質問テキスト",
  "voice": "nova",
  "response_format": "mp3"
}
```

**レスポンス:** mp3バイナリ

**キャッシュ:** `question_audios` テーブルに言語別で永続キャッシュ。同一質問・同一言語は再生成しない。

**コスト:** $15/100万文字

---

### API-6: 記事本文生成（OpenAI GPT-4o-mini）

```
エンドポイント: https://api.openai.com/v1/chat/completions
認証:           Authorization: Bearer {GPT_API_KEY}
モデル:         gpt-4o-mini
Temperature:    0.4
```

**生成ステップ:**

| Step | 処理 | JSON Mode |
|------|------|-----------|
| 0 | メタ情報生成（code, description, keyword） | Yes |
| 1 | 記事構成生成（H2/H3見出し一覧） | Yes |
| 2a | 導入文生成 | No |
| 2b | 各セクション本文生成（300-500文字） | No |
| 2c | まとめ生成 | No |

---

### API-7: 記事メタ生成（Google Gemini）

```
エンドポイント: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent
メソッド:       POST
認証:           クエリパラメータ key={GEMINI_API_KEY}
Content-Type:   application/json
```

**リクエスト:**
```json
{
  "contents": [{"parts": [{"text": "プロンプト"}]}],
  "generationConfig": {"response_mime_type": "application/json"}
}
```

**リトライ:** MAX_RETRIES=3、JSON抽出失敗時に再試行

---

### API-8: メディア処理（ffmpeg）

```
コマンド: ffmpeg -y -i {video_path} -vn -acodec pcm_s16le -ar 16000 -ac 1 {output.wav}

用途: 動画ファイルから音声を抽出（→ Whisper STTに渡す）
出力: 16kHz モノラル WAV（Whisper推奨フォーマット）
```

## 2.3 アバターAPI（将来実装）

現状はCSSで固定表示（`content: 'AI'`）。将来的に以下を検討:

| 方式 | 説明 | コスト |
|------|------|--------|
| **A: 静的画像** | プリセット画像 + カスタムアップロード | 無料 |
| **B: D-ID / HeyGen** | リアルタイムアバター動画生成 | $25-50/月 |
| **C: Simli / Tavus** | 対話型AIアバター | $30-100/月 |

**推奨**: Phase 1ではOption A（静的画像）で実装し、ニーズに応じてB/Cを検討。

## 2.4 月額コストサマリー（100面接/月）

| API | 使用量 | 現在コスト | 推奨後コスト |
|-----|--------|-----------|-------------|
| 回答評価 LLM | 500回 x ~1000tokens | ~$45 | **~$0.08** (4o-mini) |
| 面接要約 LLM | 100回 x ~2500tokens | ~$18 | **~$3.00** (4o) |
| STT (Whisper) | 250分 | $1.50 | $1.50 |
| TTS | 50,000文字 | $0.75 | $0.75 |
| **API合計** | | **~$65** | **~$5.33** |

> LLMモデル変更だけで**月額コスト約92%削減**。

---

# 3. DB設計書（ER図）最終版

## 3.1 ER図

```
                    ┌─────────────┐
                    │   admins     │
                    │─────────────│
                    │ id (PK)     │
                    │ email       │
                    │ encrypted_pw│
                    └─────────────┘

┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│   clients    │────▶│  situations  │────▶│    questions      │
│─────────────│  1:N │──────────────│ 1:N │──────────────────│
│ id (PK)     │     │ id (PK)      │     │ id (PK)          │
│ email       │     │ title        │     │ situation_id (FK) │
│ encrypted_pw│     │ description  │     │ question_text     │
└─────────────┘     │ client_id(FK)│     │ question_type     │
                    │ language     │     │ options (JSON)    │
                    │ archived     │     │ order             │
                    └──────┬───────┘     └────────┬─────────┘
                           │                      │
                           │                      │ 1:N
                           │                      ▼
                           │             ┌──────────────────┐
                           │             │ question_audios   │
                           │             │──────────────────│
                           │             │ id (PK)          │
                           │             │ question_id (FK) │
                           │             │ language          │
                           │             │ audio (Storage)   │
                           │             └──────────────────┘
                           │
┌─────────────┐            │
│   users      │            │
│─────────────│            │
│ id (PK)     │            │
│ email       │     ┌──────▼──────────────┐
│ encrypted_pw│────▶│    interviews        │
│ name        │ 1:N │─────────────────────│
└─────────────┘     │ id (PK)             │
                    │ user_id (FK)        │
                    │ situation_id (FK)   │
                    │ status (enum 0-4)   │
                    │ language            │
                    │ started_at          │
                    │ ended_at            │
                    │ UNIQUE(user,sit)    │
                    └──────┬──────────────┘
                           │
              ┌────────────┼────────────┐
              │ 1:N                     │ 1:1
              ▼                         ▼
┌──────────────────────┐  ┌──────────────────────┐
│ interview_responses   │  │ interview_results     │
│──────────────────────│  │──────────────────────│
│ id (PK)              │  │ id (PK)              │
│ interview_id (FK)    │  │ interview_id (FK,UQ) │
│ question_id (FK)     │  │ final_status (enum)  │
│ audio_transcript     │  │ results_data (JSON)  │
│ evaluation_status    │  │  - total_questions   │
│ evaluation_data(JSON)│  │  - answered_questions│
│  - relevance_score   │  │  - average_score     │
│  - correctness_score │  │  - summary           │
│  - clarity_score     │  │  - strengths[]       │
│  - final_score       │  │  - weaknesses[]      │
│  - passed            │  │  - recommendation    │
│  - ai_reasoning      │  └──────────────────────┘
│ answer_audio(Storage)│
│ answer_video(Storage)│
│ UNIQUE(intv,quest)   │
└──────────────────────┘
```

## 3.2 全テーブル定義

### admins

| カラム | 型 | 制約 |
|--------|-----|------|
| id | integer | PK |
| email | string | NOT NULL, UNIQUE |
| encrypted_password | string | |
| reset_password_token | string | UNIQUE |
| reset_password_sent_at | datetime | |
| remember_created_at | datetime | |
| created_at / updated_at | datetime | |

### clients

admins と同一構造。

### users

| カラム | 型 | 制約 |
|--------|-----|------|
| id | integer | PK |
| email | string | NOT NULL, UNIQUE |
| encrypted_password | string | |
| name | string | |
| reset_password_token | string | UNIQUE |
| reset_password_sent_at | datetime | |
| remember_created_at | datetime | |
| created_at / updated_at | datetime | |

### situations

| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | integer | PK | |
| title | string | NOT NULL | |
| description | text | | |
| client_id | integer | NOT NULL | FK欠落（要追加） |
| language | string | NOT NULL, default='en' | 'en' / 'ja' |
| archived | boolean | NOT NULL, default=false | |
| created_at / updated_at | datetime | | |

**インデックス:** client_id
**推奨追加インデックス:** (client_id, archived)
**推奨追加カラム:** min_score_required (integer), fail_policy (string)

### questions

| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | integer | PK | |
| situation_id | integer | NOT NULL | FK |
| question_text | text | NOT NULL | |
| question_type | string | NOT NULL | descriptive/choice/mcq |
| options | json | | MCQ時: {choices:[], correct:N} |
| order | integer | | 表示順 |
| created_at / updated_at | datetime | | |

**インデックス:** situation_id
**推奨追加インデックス:** (situation_id, order)

### question_audios

| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | integer | PK | |
| question_id | integer | NOT NULL | FK |
| language | string | NOT NULL, default='en' | |
| audio | ActiveStorage | | TTS生成mp3 |
| created_at / updated_at | datetime | | |

**インデックス:** (question_id, language) UNIQUE, question_id

### interviews

| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | integer | PK | |
| user_id | integer | NOT NULL | FK |
| situation_id | integer | NOT NULL | FK |
| status | integer | NOT NULL, default=0 | enum: 0-4 |
| language | string | NOT NULL, default='en' | |
| started_at | datetime | | |
| ended_at | datetime | | |
| created_at / updated_at | datetime | | |

**インデックス:** (user_id, situation_id) UNIQUE, user_id, situation_id
**推奨追加インデックス:** (status, created_at)

**Enum定義:**
```
0: not_started → 1: in_progress → 2: completed
                                 → 3: failed
                                 → 4: abandoned
```

### interview_responses

| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | integer | PK | |
| interview_id | integer | NOT NULL | FK |
| question_id | integer | NOT NULL | FK |
| audio_transcript | text | NOT NULL | STT結果 or テキスト入力 |
| evaluation_status | integer | default=0 | enum: 0-3 |
| evaluation_data | json | | LLM評価結果 |
| answer_audio | ActiveStorage | | 音声ファイル |
| answer_video | ActiveStorage | | 動画ファイル |
| created_at / updated_at | datetime | | |

**インデックス:** (interview_id, question_id) UNIQUE, interview_id, question_id, evaluation_status

**evaluation_data JSONスキーマ:**
```json
{
  "relevance_score": 85,
  "correctness_score": 80,
  "clarity_score": 90,
  "final_score": 84.0,
  "passed": true,
  "evaluation_feedback": "...",
  "ai_reasoning": "..."
}
```

### interview_results

| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | integer | PK | |
| interview_id | integer | NOT NULL, UNIQUE | FK |
| final_status | integer | | enum: 0-2 |
| results_data | json | | 総合結果 |
| created_at / updated_at | datetime | | |

**インデックス:** interview_id (UNIQUE), final_status

**results_data JSONスキーマ:**
```json
{
  "total_questions": 5,
  "answered_questions": 5,
  "skipped_questions": 0,
  "average_score": 82.5,
  "passed_count": 4,
  "summary": "総合評価テキスト",
  "strengths": ["強み1", "強み2"],
  "weaknesses": ["改善点1"],
  "recommendation": "採用推奨",
  "conversation_log": [...],
  "responses_summary": [...]
}
```

### answers（レガシー — 削除予定）

| カラム | 型 | 制約 |
|--------|-----|------|
| id | integer | PK |
| user_id | integer | NOT NULL |
| situation_id | integer | NOT NULL |
| responses | json | 全回答を格納 |
| started_at / finished_at | datetime | |

> interview_responses で完全に置き換え済み。Phase 2 で削除予定。

## 3.3 推奨スキーマ変更（最終版）

### 追加カラム

```ruby
# situations テーブル
add_column :situations, :min_score_required, :integer, default: 70
add_column :situations, :fail_policy, :string, default: 'average'
  # 'per_question' | 'average' | 'consecutive'

# interview_responses テーブル
add_column :interview_responses, :time_spent_seconds, :integer

# questions テーブル
add_column :questions, :time_limit_seconds, :integer
add_column :questions, :difficulty_level, :string, default: 'medium'
```

### 追加インデックス

```ruby
add_index :interviews, [:status, :created_at]
add_index :questions, [:situation_id, :order]
add_index :situations, [:client_id, :archived]
add_index :interview_responses, :created_at
```

### 追加FK制約

```ruby
add_foreign_key :situations, :clients
add_foreign_key :answers, :users
```

---

# 4. 内部API設計書

## 4.1 エンドポイント一覧

| メソッド | パス | アクション | 認証 |
|---------|------|-----------|------|
| POST | /api/interviews/start | 面接開始 | User |
| GET | /api/interviews/:id/next_question | 次の質問取得 | User |
| POST | /api/interviews/:id/submit_answer | 回答送信 | User |
| POST | /api/interviews/:id/complete | 面接完了 | User |
| GET | /api/interviews/:id/status | 状態取得 | User |

## 4.2 各エンドポイント詳細

### POST /api/interviews/start

**リクエスト:**
```json
{
  "situation_id": 1,
  "language": "ja"
}
```

**成功レスポンス (200):**
```json
{
  "success": true,
  "interview_id": 42,
  "status": "in_progress",
  "total_questions": 5,
  "language": "ja"
}
```

**エラーレスポンス (422):**
```json
{
  "success": false,
  "error": "Validation failed: ..."
}
```

---

### GET /api/interviews/:id/next_question

**成功レスポンス — 質問あり (200):**
```json
{
  "success": true,
  "question": {
    "id": 10,
    "question_text": "自己紹介をお願いします",
    "question_type": "descriptive",
    "options": null,
    "order": 1
  },
  "audio_url": "/rails/active_storage/blobs/.../question.mp3",
  "progress": {"current": 1, "total": 5}
}
```

**成功レスポンス — 全問完了 (200):**
```json
{
  "success": true,
  "interview_complete": true,
  "message": "All questions answered"
}
```

---

### POST /api/interviews/:id/submit_answer

**リクエスト (multipart/form-data):**

| パラメータ | 型 | 必須 | 備考 |
|-----------|-----|------|------|
| question_id | integer | Yes | |
| text_answer | string | いずれか1つ | テキスト回答 |
| audio_file | file | いずれか1つ | 音声ファイル |
| video_file | file | いずれか1つ | 動画ファイル |
| selected_option | string | MCQ時 | 選択肢テキスト |

**成功レスポンス (200):**
```json
{
  "success": true,
  "response_id": 101,
  "message": "Answer submitted successfully"
}
```

**処理フロー:**
1. 音声/動画ファイル → STT変換（Whisper）
2. InterviewResponse 作成
3. EvaluateInterviewResponseJob を非同期実行
4. レスポンス返却

---

### POST /api/interviews/:id/complete

**成功レスポンス (200):**
```json
{
  "success": true,
  "result": {
    "final_status": "passed",
    "average_score": 82.5,
    "total_questions": 5,
    "answered_questions": 5,
    "summary": "バランスの取れた回答でした",
    "strengths": ["論理的な説明力", "具体的な経験の提示"],
    "weaknesses": ["回答がやや冗長"],
    "recommendation": "次のステップへ進むことを推奨"
  }
}
```

**エラーレスポンス (400):**
```json
{
  "success": false,
  "error": "Cannot complete: 2 responses still pending evaluation"
}
```

---

### GET /api/interviews/:id/status

**成功レスポンス (200):**
```json
{
  "success": true,
  "interview": {
    "id": 42,
    "status": "in_progress",
    "progress": {"answered": 3, "total": 5},
    "started_at": "2026-03-04T10:00:00+09:00"
  }
}
```

## 4.3 認証方式

| 条件 | 方式 |
|------|------|
| 通常 | Devise `authenticate_user!` (セッションCookie) |
| テストモード | `AI_INTERVIEW_TEST_MODE=true` → `User.find_by(email: 'test@interview.com')` |
| 認可 | `@interview.user == current_user` (不一致 → 403) |

> **注意**: CSRF保護は `skip_before_action :verify_authenticity_token` で無効化中。API tokenベースの認証への移行を推奨。

## 4.4 非同期ジョブ

| ジョブ | キュー | リトライ | 処理内容 |
|--------|--------|---------|---------|
| EvaluateInterviewResponseJob | default | 5秒x3回 | LLM評価 → evaluation_data更新 |
| GenerateColumnBodyJob | article_generation | ReadTimeout時3回 | GPT記事本文生成 |
| GenerateChildColumnsJob | default | なし | Gemini子記事バッチ生成 |

---

## 付録: マイグレーション履歴

| ファイル | 内容 |
|---------|------|
| 20251110051059 | columns テーブル作成 |
| 20251110101453 | admins テーブル (Devise) |
| 20251208172754 | columns に service_type 追加 |
| 20260104062338 | columns に code 追加 |
| 20260104063939 | friendly_id_slugs テーブル |
| 20260111102216 | columns に structure 追加 |
| 20260111130341 | contracts テーブル |
| 20260129051627 | columns に prompt 追加 |
| 20260205071350 | users テーブル (Devise) |
| 20260205071353 | clients テーブル (Devise) |
| 20260205071509 | situations テーブル |
| 20260205071533 | questions テーブル |
| 20260205071546 | answers テーブル |
| 20260207120000 | **interviews / interview_responses / interview_results** |
| 20260208120000 | ActiveStorage テーブル |
| 20260208121000 | interviews.language / users.name / situations.language,archived |
| 20260208122000 | question_audios テーブル |

---

*2026-03-04 時点 / master ブランチ*
