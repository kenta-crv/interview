# AI面接インタビューシステム — Day 1・Day 2 報告書

**作成日:** 2026-03-02 | **リポジトリ:** tianzhongyoushi178/AI_Interviewer | **ブランチ:** master

---

## 目次

- [Day 1: 現状分析・要件確定](#day-1-現状分析要件確定)
- [Day 2: フローチャート・画面遷移図](#day-2-フローチャート画面遷移図)

---

# Day 1: 現状分析・要件確定

## 1. プロジェクト概要

| 項目 | 内容 |
|------|------|
| フレームワーク | Rails 6.1.7 / Ruby 3.1.6 |
| DB | SQLite3 (開発/本番共通) |
| 認証 | Devise (Admin/Client/User の3ロール) |
| テンプレート | Slim |
| 非同期 | Sidekiq + ActiveJob |
| AI連携 | OpenAI (GPT-4, Whisper, TTS-1) / Claude / Gemini |

**主要機能**: AI面接システム + コンテンツ管理 + 契約管理

### 主要コンポーネント

- **API**: `Api::InterviewsController` — start / next_question / submit_answer / complete / status
- **サービス層**: SessionManager（ライフサイクル）/ ResponseEvaluator（AI評価）/ QuestionSelector（質問選択+TTS）/ LLMClient（GPT-4/Claude）/ STTClient（Whisper）/ TTSClient

---

## 2. データモデル

```
Client ─── Situation ─── Question ─── QuestionAudio
                │
                └── Interview (User + Situation = UNIQUE)
                        ├── InterviewResponse (評価データJSON)
                        └── InterviewResult (結果データJSON)
```

**全16テーブル** — うち面接系6テーブル（interviews, interview_responses, interview_results, situations, questions, question_audios）+ レガシー1テーブル（answers: **削除推奨**）

### 主要Enum

| モデル | Enum | 値 |
|--------|------|-----|
| Interview | status | not_started(0), in_progress(1), completed(2), failed(3), abandoned(4) |
| InterviewResponse | evaluation_status | pending(0), evaluating(1), completed(2), failed(3) |
| InterviewResult | final_status | passed(0), failed(1), incomplete(2) |

---

## 3. 不足項目

**カラム（高優先）**: situations に `min_score_required`, `difficulty_level`
**インデックス**: interviews(status,created_at) / questions(situation_id,order) / situations(client_id,archived)
**FK制約**: answers→users, situations→clients, columns→columns — いずれも欠落

---

## 4. 技術的負債（19件）

### 高優先度（セキュリティ）6件

| 問題 | リスク |
|------|--------|
| テストモード認証バイパス | 本番で全認証スキップ可能 |
| CSRF保護なし（API） | トークン検証スキップ |
| ファイルアップロード検証なし | サイズ・形式チェックなし |
| APIキー起動時検証なし | nil状態でランタイムエラー |
| メール同期送信 | SMTP失敗で500エラー |
| エラー詳細の本番表示 | スタックトレース露出 |

### 中優先度（パフォーマンス）5件

本番SQLite / Markdown毎回パース / TTS一時ファイル蓄積 / sleep()レート制限 / 本番ジョブ非同期未使用

### 低優先度（保守性）8件

テストカバレッジ0% / 新旧面接フロー共存 / ハードコード値多数 / APIレスポンス不統一 / ジョブ失敗通知なし / Rails 6.1 EOL / Puma 3.x / Gemfile重複

---

## 5. 外部ツール・費用感

### 推奨変更

| 用途 | 現在 → 推奨 | 効果 |
|------|------------|------|
| 回答評価LLM | GPT-4 → **GPT-4o-mini** | **コスト1/40** |
| 面接要約LLM | GPT-4 → **GPT-4o** | 高品質+コスト削減 |
| STT/TTS | 現状維持 | 最安値 |
| DB | SQLite → **PostgreSQL** | 本番必須 |

### 月額コスト見積もり（100面接/月）

| 構成 | 月額 |
|------|------|
| 最小構成（Render） | **約$10（約1,600円）** |
| 推奨構成（Heroku Standard） | **約$36（約5,300円）** |
| 本番構成（Heroku + Postgres Standard） | **約$81（約12,000円）** |

> AI APIコストは月$2〜$5。コスト支配的なのはインフラ。

---

## 6. アクションロードマップ

| Phase | 期間 | 内容 |
|-------|------|------|
| **1: セキュリティ** | 即座 | テストモード隔離 / アップロード検証 / GPT-4→4o-mini / 本番エラー非表示 / メール非同期化 |
| **2: 短期改善** | 1-2週 | SQLite→PostgreSQL / Answer廃止 / インデックス追加 / APIレスポンス統一 / FK制約追加 |
| **3: 中期改善** | 2-4週 | RSpec導入 / ハードコード値のDB化 / TTSクリーンアップ / Sidekiq本番設定 / Rails 7.0+検討 |

---

# Day 2: フローチャート・画面遷移図

## 1. システム全体アーキテクチャ

```
┌─────────────── ブラウザ (User) ───────────────┐
│  Step1: 面接選択 → Step2: Q&A → Step3: 結果  │
└──────┬──────────────┬───────────────┬──────────┘
  POST /start   POST /submit_answer  POST /complete
       │              │                    │
┌──────▼──────────────▼────────────────────▼─────┐
│              Rails API サーバー                  │
│  SessionManager ←→ QuestionSelector             │
│       ↕                  ↕                       │
│  ResponseEvaluator    LLMClient / STTClient     │
└──────────────────────────────────────────────────┘
```

## 2. 面接実行フロー

```
/interview アクセス
    │
    ▼
[Step 1] Situation選択 + 言語選択
    │ POST /api/interviews/start
    ▼
[Step 2] 質問ループ
    │  GET /next_question → 質問表示(+TTS音声)
    │  ユーザー回答（テキスト/音声/動画/MCQ）
    │  POST /submit_answer → 音声ならSTT変換 → InterviewResponse作成
    │  → EvaluateInterviewResponseJob（非同期評価）
    │  → 次の質問へ（ループ）
    │
    │  全問回答完了
    │ POST /api/interviews/:id/complete
    ▼
[Step 3] 結果表示
    合否判定 / 平均スコア / 総評 / 強み・改善点 / 推薦コメント
```

## 3. Client管理画面フロー

- **Situation CRUD**: /situations — 一覧→新規作成/編集/削除（dependent :destroy で連鎖削除）
- **Question CRUD**: /situations/:id/questions — 質問タイプ（descriptive/choice/mcq）+ 表示順序管理
- **アバター**: 将来実装予定（situations に avatar_type, avatar_name カラム追加）

## 4. リジェクト判定ロジック

### スコア計算式

```
個別: final_score = Relevance×0.4 + Correctness×0.4 + Clarity×0.2
全体: average_score = Σ(final_score) ÷ 回答数
合格: average_score >= 70 → PASSED
MCQ: 正解=100点 / 不正解=0点
```

### ステータス遷移

```
Interview:  not_started → in_progress → completed / failed / abandoned
Response:   pending → evaluating → completed / failed
Result:     average >= 70 → passed / < 70 → failed
```

### 即時リジェクト（要改善）

現在: **1問でもscore < 70 → 面接全体がfail**（厳しすぎる）

改善案:
- **A（推奨）**: 全問終了後に平均スコアで判定
- **B**: 3問連続失敗で打ち切り
- **C**: Situationごとにfail_policyを設定可能に

## 5. 認証・エラーハンドリング

**認証**: Devise 3モデル（Admin/Client/User）、テストモード時は認証スキップ（`test@interview.com`を使用）

**APIエラー**: 全エンドポイント `{success: false, error: "..."}` 形式（ただしHTTPステータスは不統一）

| エンドポイント | 主なエラー |
|--------------|-----------|
| start | 422: バリデーション失敗 |
| submit_answer | 400: 回答なし/重複回答/STT失敗、404: 質問不明 |
| complete | 400: 未評価回答あり、500: LLM生成失敗 |

---

## 付録: 環境変数

| 変数名 | 用途 |
|--------|------|
| `OPENAI_API_KEY` | LLM/STT/TTS |
| `CLAUDE_API_KEY` | Claude API |
| `GEMINI_API_KEY` | Gemini API |
| `GPT_API_KEY` | 記事生成用 |
| `AI_INTERVIEW_TEST_MODE` | テストモード |
| `EMAIL_PASSWORD` | SMTP認証 |

---

*2026-03-02 時点 / master ブランチ / commit 0875803*
