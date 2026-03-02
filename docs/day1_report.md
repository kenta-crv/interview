# Day 1 — 現状分析・要件確定 レポート

**作成日:** 2026-03-02

---

## 1. プロジェクト概要

| 項目 | 内容 |
|------|------|
| フレームワーク | Rails 6.1.7 |
| Ruby | 3.1.6 |
| DB | SQLite3 (開発/本番共通) |
| テンプレート | Slim |
| 認証 | Devise (3ロール: Admin/Client/User) |
| 非同期処理 | Sidekiq |
| ファイル管理 | ActiveStorage + CarrierWave (混在) |

**主要機能**: AI面接システム + コンテンツ管理(ブログ記事生成) + 契約管理

### コントローラー構成

| コントローラー | 責務 |
|---|---|
| `TopsController` | ランディングページ・ジャンルLP表示 |
| `ColumnsController` | 記事CRUD・AI生成・Markdown処理 |
| `SituationsController` | 面接シナリオ管理（クライアント用） |
| `QuestionsController` | 面接質問CRUD |
| `AnswersController` | 回答記録（旧システム） |
| `ContractsController` | 問い合わせ・契約管理 |
| `Api::InterviewsController` | AI面接REST API (start/next_question/submit_answer/complete/status) |
| `Admin::InterviewResultsController` | 管理者向け面接結果ビューア |
| `Client::InterviewResultsController` | クライアント向け面接結果ビューア |

### サービス層

| サービス | 責務 |
|---------|------|
| `InterviewEngine::SessionManager` | 面接セッションのライフサイクル管理 |
| `InterviewEngine::ResponseEvaluator` | 回答のAI評価・スコア計算 (PASS_THRESHOLD=70) |
| `InterviewEngine::QuestionSelector` | 質問選択・TTS音声生成 |
| `InterviewEngine::LLMClient` | OpenAI/Claude API連携 |
| `InterviewEngine::STTClient` | 音声→テキスト (Whisper API) |
| `InterviewEngine::TTSClient` | テキスト→音声 (OpenAI TTS) |
| `InterviewEngine::MediaProcessor` | ビデオ→音声抽出 (ffmpeg) |
| `GptArticleGenerator` | GPT-4o-miniによる記事本文生成 |
| `GptPillarGenerator` | 親記事(Pillar)生成 |
| `GeminiColumnGenerator` | Geminiによる子記事タイトル一括生成 |

### 非同期ジョブ

| ジョブ | キュー | リトライ |
|------|--------|---------|
| `EvaluateInterviewResponseJob` | default | 5秒間隔3回 |
| `GenerateColumnBodyJob` | article_generation | Net::ReadTimeout時3回 |
| `GenerateChildColumnsJob` | default | - |

---

## 2. データモデル（ER関連図）

```
Admin (独立)

Client (1) ─── (多) Situation
                      │
                      ├── (多) Question ─── (多) QuestionAudio
                      │
                      ├── (多) Interview (user_id + situation_id = UNIQUE)
                      │        │
                      │        ├── (多) InterviewResponse (interview_id + question_id = UNIQUE)
                      │        │        ├── answer_audio (ActiveStorage)
                      │        │        ├── answer_video (ActiveStorage)
                      │        │        └── evaluation_data (JSON: scores/feedback)
                      │        │
                      │        └── (1) InterviewResult
                      │                 └── results_data (JSON: summary/strengths/weaknesses)
                      │
                      └── (多) Answer ← レガシー（削除候補）

User (1) ─── (多) Interview
         └── (多) Answer ← レガシー（削除候補）
```

### 全テーブル一覧

| テーブル | 用途 | 状態 |
|---------|------|------|
| **admins** | 管理者 | 使用中 |
| **users** | 受験者 (email, encrypted_password, name) | 使用中 |
| **clients** | 採用企業 | 使用中 |
| **situations** | 面接シナリオ (title, description, client_id, language, archived) | 使用中 |
| **questions** | 面接質問 (situation_id, question_text, question_type, options, order) | 使用中 |
| **question_audios** | 質問の多言語音声 (question_id, language) + ActiveStorage | 使用中 |
| **interviews** | 面接セッション (user_id, situation_id, status, language, started_at, ended_at) | 使用中（新） |
| **interview_responses** | 個別回答+AI評価 (interview_id, question_id, audio_transcript, evaluation_status, evaluation_data) | 使用中（新） |
| **interview_results** | 面接総合結果 (interview_id, final_status, results_data) | 使用中（新） |
| **answers** | 旧回答形式 (user_id, situation_id, responses JSON) | **削除候補** |
| **columns** | ブログ記事 (title, body, genre, code, article_type, parent_id) | 面接と無関係 |
| **contracts** | 契約情報 | 面接と無関係 |
| **friendly_id_slugs** | URL Slug管理 | 面接と無関係 |
| active_storage_* (3テーブル) | ファイル保存 | Rails内部 |

### モデル詳細

#### Interview
- **enum status**: not_started(0), in_progress(1), completed(2), failed(3), abandoned(4)
- **enum language**: en, ja
- **バリデーション**: user_id + situation_id UNIQUE, 前回completed/failed チェック, 最低1問必要
- **メソッド**: start!, complete!, fail!, duration, progress_percentage

#### InterviewResponse
- **enum evaluation_status**: pending(0), evaluating(1), completed(2), failed(3)
- **store evaluation_data**: relevance_score, correctness_score, clarity_score, final_score, evaluation_feedback, passed, ai_reasoning
- **ActiveStorage**: answer_audio, answer_video

#### InterviewResult
- **enum final_status**: passed(0), failed(1), incomplete(2)
- **store results_data**: total_questions, answered_questions, skipped_questions, average_score, responses_summary, summary, conversation_log, strengths, weaknesses, recommendation

#### Answer (レガシー)
- responses JSONに全回答を詰め込む旧構造
- バリデーションなし、ビジネスロジックなし
- InterviewResponseで完全に置き換え済み → **削除推奨**

---

## 3. 不足テーブル・カラムの特定

### 不足テーブル

| テーブル | 用途 | 優先度 |
|---------|------|--------|
| audit_logs | 状態変更履歴 | 中 |
| interview_schedules | 面接予約日時管理 | 低 |
| notification_settings | メール通知制御 | 低 |

### 不足カラム

| テーブル | 推奨カラム | 理由 | 優先度 |
|---------|-----------|------|--------|
| **situations** | min_score_required, difficulty_level | 合否基準の柔軟化 | 高 |
| **users** | phone, role, avatar_url | プロフィール拡充 | 中 |
| **interview_responses** | time_spent_seconds | 回答時間の計測 | 中 |
| **questions** | time_limit_seconds, difficulty_level, competency_category | 質問の細分類 | 中 |
| **interviews** | notes, scheduled_at | メモ・予約機能 | 低 |

### 不足インデックス

| テーブル | カラム | 理由 |
|---------|--------|------|
| interviews | (status, created_at) | ステータス検索の高速化 |
| interview_responses | created_at | 時系列検索 |
| questions | (situation_id, order) | 質問一覧取得の最適化 |
| situations | (client_id, archived) | アクティブシナリオ検索 |

### 外部キー制約の欠落

| From | To | 状態 |
|------|-----|------|
| answers.user_id | users.id | FK制約なし (インデックスのみ) |
| situations.client_id | clients.id | FK制約なし (インデックスのみ) |
| columns.parent_id | columns.id | FK制約なし |

---

## 4. 技術的負債の洗い出し

### 高優先度（セキュリティ）

| # | 問題 | ファイル | リスク |
|---|------|---------|--------|
| 1 | **テストモード認証バイパス** | `api/interviews_controller.rb:258-260` | 本番で`AI_INTERVIEW_TEST_MODE=true`だと全認証スキップ |
| 2 | **CSRF保護なし** | `api/interviews_controller.rb:4` | `skip_before_action :verify_authenticity_token` |
| 3 | **ファイルアップロード検証なし** | `api/interviews_controller.rb:75-86` | サイズ・形式チェックなし、DoS攻撃可能 |
| 4 | **APIキーの起動時検証なし** | `llm_client.rb:7-11` | nil状態でランタイムエラー |
| 5 | **メール同期送信** | `contracts_controller.rb:17-18` | SMTP失敗で500エラー |
| 6 | **エラー詳細の本番表示** | `production.rb:14` | `consider_all_requests_local = true` でスタックトレース露出 |

### 中優先度（パフォーマンス）

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 7 | **本番SQLite** | `database.yml:29-32` | 同時アクセスでDBロック多発 |
| 8 | **Markdown毎回パース** | `columns_controller.rb:66-81` | HTMLキャッシュなし |
| 9 | **TTSの一時ファイル蓄積** | `tts_client.rb:44-52` | `tmp/interview_audio`のクリーンアップなし |
| 10 | **sleep()によるレート制限** | `gpt_pillar_generator.rb:82-86` | `sleep(1.0)`で対応(脆弱) |
| 11 | **本番ジョブが非同期未使用** | `production.rb:16` | `queue_adapter = :async` (Sidekiq未使用) |

### 低優先度（保守性）

| # | 問題 | 詳細 |
|---|------|------|
| 12 | テストカバレッジ0% | 全テストファイルが空のスケルトン |
| 13 | Answer(旧)とInterview(新)の共存 | 2つの面接フローが混在 |
| 14 | ハードコード値多数 | モデル名、合格点(70)、メールアドレス、評価重み(0.4/0.4/0.2)等 |
| 15 | APIエラーレスポンスが不統一 | メソッドごとに異なるJSON構造 |
| 16 | ジョブ失敗時の通知機構なし | 失敗がサイレントに消える |
| 17 | Rails 6.1 (EOL済み) | セキュリティアップデート終了 (2023年12月) |
| 18 | Puma 3.x (古い) | 現在6.x系 |
| 19 | Gemfile重複 | kramdownが2回定義 |

### ハードコードされた値一覧

| ファイル | 値 | 用途 |
|---------|-----|------|
| `response_evaluator.rb:4` | `PASS_THRESHOLD = 70` | 合格スコア |
| `response_evaluator.rb:79` | `0.4, 0.4, 0.2` | 評価重み (relevance/correctness/clarity) |
| `llm_client.rb:136` | `model: 'gpt-4'` | LLMモデル（旧版） |
| `stt_client.rb:33` | `model: 'whisper-1'` | STTモデル |
| `tts_client.rb:34` | `voice: 'nova'` | TTS音声 |
| `gpt_article_generator.rb:9` | `MODEL_NAME = "gpt-4o-mini"` | 記事生成モデル |
| `application.rb:24` | `'smtp.lolipop.jp', 'info@okey.work'` | SMTP設定 |

---

## 5. 外部ツール選定・費用感

### 現在の実装状況

| 用途 | 現在のサービス | APIキー環境変数 |
|------|--------------|----------------|
| 回答評価 LLM | OpenAI GPT-4 | `OPENAI_API_KEY` |
| 代替 LLM | Claude 3 Sonnet (claude-3-sonnet-20240229) | `CLAUDE_API_KEY` |
| STT | OpenAI Whisper (whisper-1) | `OPENAI_API_KEY` |
| TTS | OpenAI TTS-1 (voice: nova) | `OPENAI_API_KEY` |
| 記事生成 | OpenAI GPT-4o-mini | `GPT_API_KEY` |
| 記事メタ生成 | Google Gemini 2.0 Flash | `GEMINI_API_KEY` |
| メディア処理 | ffmpeg (ローカル) | - |

### 推奨API構成

| 用途 | 現在 | 推奨変更 | コスト効果 |
|------|------|---------|-----------|
| **回答評価(LLM)** | GPT-4 ($30/$60 per 1M tokens) | **GPT-4o-mini** ($0.15/$0.60) | **コスト1/40に削減** |
| **面接要約(LLM)** | GPT-4 | **GPT-4o** ($2.50/$10) | 高品質+コスト削減 |
| **STT** | OpenAI Whisper ($0.006/分) | **現状維持** | 最安値 |
| **TTS** | OpenAI TTS-1 ($15/100万文字) | **現状維持** or Google TTS ($4) | 品質優先なら維持 |
| **DB** | SQLite3 | **PostgreSQL** | 本番必須 |
| **デプロイ** | ローカル | **Render** or **Heroku** | Rails対応良好 |

### LLM 比較表

| モデル | 入力 ($/1M tokens) | 出力 ($/1M tokens) | 推奨用途 |
|--------|------|------|----------|
| **GPT-4o-mini** | $0.15 | $0.60 | **回答評価（推奨）** |
| GPT-4o | $2.50 | $10.00 | 面接要約 |
| Claude 3.5 Sonnet | $3.00 | $15.00 | 面接要約（代替） |
| Claude 3.5 Haiku | $0.80 | $4.00 | 回答評価（代替） |
| Gemini 2.5 Flash | $0.30 | $2.50 | 低コスト案 |

### STT 比較表

| サービス | 料金 (/分) | 日本語精度 | 推奨 |
|----------|-----------|-----------|------|
| **OpenAI Whisper** | $0.006 | 高 | **現状維持** |
| GPT-4o Mini Transcribe | $0.003 | 高 | コスト削減案 |
| Google Speech-to-Text | $0.016~$0.024 | 高 | エンタープライズ向け |
| AWS Transcribe | $0.024 | 高 | AWS連携 |

### TTS 比較表

| サービス | 料金 (/100万文字) | 品質 | 推奨 |
|----------|------------------|------|------|
| **OpenAI TTS-1** | $15.00 | 自然 | **現状維持** |
| Google Cloud TTS Standard | $4.00 | 普通 | コスト削減案 (無料枠400万文字/月) |
| Amazon Polly Standard | $4.80 | 普通 | 無料枠500万文字/月 |

### インフラ比較表

| サービス | 最小構成 (/月) | 中規模 (/月) |
|----------|---------------|-------------|
| **Render** | $7 (Starter) | $25 (Standard) |
| Heroku | $7 (Basic) | $25 (Standard) |
| AWS EC2 | ~$8 (t2.micro) | ~$33 (t2.medium) |
| Google Cloud Run | 従量課金 | ~$20~$40 |

### DB (PostgreSQL) 比較表

| サービス | 最小構成 (/月) | 本番構成 (/月) |
|----------|---------------|---------------|
| **Render PostgreSQL** | $0 (無料/1GB) | $7~$20 |
| Heroku Postgres | $5 (Essential) | $50 (Standard-0) |
| AWS RDS | ~$12 (db.t4g.micro) | ~$25~$50 |

### 月額コスト見積もり（面接100件/月, 1面接5問, 30秒音声回答）

#### AI APIコスト

```
回答評価: 500回 x (~1000 tokens) = 入力 400K + 出力 100K tokens
面接要約: 100回 x (~2500 tokens) = 入力 200K + 出力 50K tokens
STT: 500回答 x 30秒 = 250分
TTS: 500質問 x 100文字 = 50,000文字
```

| 構成 | AI API | インフラ | **月額合計** |
|------|--------|---------|-------------|
| **最小構成** (GPT-4o-mini + Whisper + TTS-1 + Render) | ~$2.50 | ~$8 | **約$10 (約1,600円)** |
| **推奨構成** (GPT-4o-mini/4o混合 + Whisper + TTS-1 + Heroku Standard) | ~$4.50 | ~$31 | **約$36 (約5,300円)** |
| **本番構成** (GPT-4o + Whisper + TTS-1 + Heroku Standard + Postgres Standard) | ~$4.50 | ~$76 | **約$81 (約12,000円)** |

**ポイント**: AI APIコストは月100件でも$2~$5と非常に安価。コスト支配的なのはインフラ（サーバー+DB）。

---

## 6. 推奨アクションロードマップ

### Phase 1: 即座に対応（セキュリティ）
1. テストモード機能を本番環境から隔離（`Rails.env.development?`ガード追加）
2. ファイルアップロードのサイズ・形式チェック追加
3. `llm_client.rb`のモデルを`gpt-4` → `gpt-4o-mini`に更新
4. `production.rb`の`consider_all_requests_local`を`false`に変更
5. メール送信を`deliver_later`で非同期化

### Phase 2: 短期改善（1-2週間）
6. SQLite → PostgreSQL移行
7. Answerテーブル(旧システム)の廃止
8. 不足インデックス追加
9. APIエラーレスポンスの統一
10. FK制約の追加 (answers→users, situations→clients)

### Phase 3: 中期改善（2-4週間）
11. RSpecテスト導入
12. ハードコード値のDB/環境変数化
13. TTSファイルのクリーンアップJob
14. Sidekiqの本番設定（inline → Redis）
15. Rails 7.0+へのアップグレード検討

---

## 付録: 環境変数一覧

| 変数名 | 用途 | 参照箇所 |
|--------|------|---------|
| `OPENAI_API_KEY` | OpenAI API (LLM/STT/TTS) | llm_client.rb, stt_client.rb, tts_client.rb |
| `CLAUDE_API_KEY` | Claude API | llm_client.rb |
| `GEMINI_API_KEY` | Google Gemini API | gemini_column_generator.rb, gemini_pillar_generator.rb |
| `GPT_API_KEY` | OpenAI (記事生成用) | gpt_article_generator.rb, gpt_pillar_generator.rb |
| `AI_INTERVIEW_TEST_MODE` | テストモード | response_evaluator.rb, api/interviews_controller.rb |
| `EMAIL_PASSWORD` | SMTP認証 | application.rb |
| `RAILS_ALLOWED_HOST` | ホスト検証 | production.rb |
| `RAILS_MAX_THREADS` | DB接続プール | database.yml (デフォルト: 15) |
