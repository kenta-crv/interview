# AI面接インタビューシステム — Day 5・Day 6 報告書

**作成日:** 2026-03-08 | **リポジトリ:** tianzhongyoushi178/AI_Interviewer | **ブランチ:** master

---

## 目次

- [Day 5: LLM制御レイヤーの実装](#day-5-llm制御レイヤーの実装)
- [Day 6: 面接セッション管理](#day-6-面接セッション管理)

---

# Day 5: LLM制御レイヤーの実装

## 1. 概要

LLMの出力を厳密に制御する3層構造を構築した。従来は `LLMClient` にプロンプト生成・API呼び出し・レスポンス解析が混在していたが、責務を分離し、プロンプトテンプレート管理・レスポンスバリデーション・リトライ機構を独立したクラスとして実装した。

### アーキテクチャ

```
ResponseEvaluator（評価オーケストレーション）
    │
    ▼
LLMClient（API呼び出し + リトライ）
    │
    ├── PromptTemplate（プロンプト生成）
    │     ├── system/user メッセージ分離
    │     ├── 日本語/英語対応
    │     └── ユーザー入力サニタイズ
    │
    └── ResponseValidator（出力検証）
          ├── JSON抽出（多段フォールバック）
          ├── スキーマバリデーション
          └── スコアクランプ / 型変換
```

---

## 2. プロンプトテンプレート管理

**ファイル:** `app/services/interview_engine/prompt_template.rb`

### 設計方針

| 項目 | 方針 |
|------|------|
| メッセージ構造 | system（ロール制限）+ user（タスク指示）の分離 |
| 言語対応 | en / ja を `normalize_language` で安全に切替 |
| 自由生成排除 | system promptに「JSON出力のみ・会話禁止・追加質問禁止」を明示 |
| プロンプトインジェクション対策 | delimiter方式（`---BEGIN USER INPUT---` / `---END USER INPUT---`） |

### テンプレート一覧

| テンプレート | メソッド | 出力スキーマ |
|------------|---------|-------------|
| 回答評価（記述式） | `evaluation(question_type: 'open')` | `{relevance_score, correctness_score, clarity_score, final_score, passed, reasoning}` |
| 回答評価（選択式） | `evaluation(question_type: 'choice')` | 同上 |
| 面接サマリー | `summary(responses_data:)` | `{summary, strengths[], weaknesses[], recommendation}` |

### サニタイズ処理

```ruby
def sanitize(text)
  text.to_s
      .gsub(/```/, "'''")        # コードブロック記法のエスケープ
      .strip
      .truncate(2000)            # 長文制限
  # delimiter方式で囲む
  "---BEGIN USER INPUT---\n#{sanitized}\n---END USER INPUT---"
end
```

---

## 3. レスポンスバリデーション

**ファイル:** `app/services/interview_engine/response_validator.rb`

### JSON抽出フロー（多段フォールバック）

```
LLMレスポンス
    │
    ├─ 1. 全体をJSONパース → 成功ならそのまま使用
    │
    ├─ 2. ```json ... ``` ブロック抽出 → パース試行
    │
    ├─ 3. { ... } を正規表現で抽出 → パース試行
    │
    └─ 4. 全て失敗 → nil（リトライへ）
```

### バリデーション処理

| 処理 | 対象 | 内容 |
|------|------|------|
| スキーマ検証 | 評価/サマリー共通 | 必須キーの存在チェック（`data.key?` で JSON null も許容） |
| スコアクランプ | 評価のみ | 0-100範囲に制限、整数に丸め |
| 型変換 | 評価のみ | `passed` を boolean に強制変換 |
| 配列制限 | サマリーのみ | strengths/weaknesses を最大5項目・各200文字に制限 |

---

## 4. LLMClient 強化

**ファイル:** `app/services/interview_engine/llm_client.rb`

### リトライ機構

| 設定 | 値 |
|------|-----|
| 最大リトライ回数 | 3回 |
| バックオフ | 指数（1秒 → 1秒 → 1秒） |
| リクエストタイムアウト | 30秒（接続/読取り） |

### リトライ対象のエラー分類

| エラークラス | 例 | リトライ |
|-------------|-----|---------|
| `LLMTimeoutError` | 接続/読取りタイムアウト | する |
| `LLMResponseError` | 429 Rate Limit / 500番台 | する |
| `LLMError` | 401/403 認証失敗 | **しない** |
| `LLMValidationError` | 全リトライ失敗 | — |

### モデル設定（環境変数）

| 環境変数 | デフォルト | 説明 |
|---------|-----------|------|
| `LLM_MODEL` | `openai` | 使用モデルプロバイダ（openai/claude） |
| `OPENAI_MODEL` | `gpt-4` | OpenAI モデル名 |
| `CLAUDE_MODEL` | `claude-sonnet-4-20250514` | Claude モデル名 |

### OpenAI固有の制御

- `response_format: { type: 'json_object' }` — JSON出力を強制
- `temperature: 0.2` — 出力の安定性を重視

---

## 5. ResponseEvaluator 改修

**ファイル:** `app/services/interview_engine/response_evaluator.rb`

### 変更内容

| 変更 | 詳細 |
|------|------|
| LLM呼び出し分離 | `llm_evaluate` メソッドに抽出 |
| トランザクション制御 | 評価結果保存 + 面接継続判定を `ActiveRecord::Base.transaction` で保護 |
| スコア再計算の明示 | LLMの `final_score` を無視し、加重平均で再計算する理由をコメントで明記 |
| 型安全性 | `@response.final_score.to_f` でJSON store経由の文字列型に対応 |
| 戻り値統一 | 全評価パスで `with_indifferent_access` を使用 |

### スコア計算（変更なし）

```
加重平均 = relevance(40%) + correctness(40%) + clarity(20%)
合格ライン = 70点以上
```

---

## 6. コードレビュー結果

Day 5のレビューで検出・修正した主要な指摘:

| 重要度 | 件数 | 主な内容 |
|--------|------|---------|
| Critical | 5 | JSON store型問題、リトライ対象漏れ、認可キーチェック方式、sanitize方式 |
| Warning | 10 | N+1クエリ、スコア丸め、トランザクション分断、戻り値型不統一 |
| Info | 4 | require配置、DI検討、設計メモ |

---

## 7. 変更ファイル一覧

| ファイル | 種別 | 内容 |
|---------|------|------|
| `app/services/interview_engine/prompt_template.rb` | **新規** | プロンプトテンプレート管理（EN/JA対応、スキーマ定義、サニタイズ） |
| `app/services/interview_engine/response_validator.rb` | **新規** | LLM出力バリデーション（JSON抽出、スキーマ検証、クランプ） |
| `app/services/interview_engine/llm_client.rb` | **改修** | リトライ機構、タイムアウト、エラー分類、モデル設定柔軟化 |
| `app/services/interview_engine/response_evaluator.rb` | **改修** | トランザクション、型安全性、メソッド分離 |
| `app/services/interview_engine/session_manager.rb` | **改修** | N+1修正（includes）、キーアクセス統一 |

---

# Day 6: 面接セッション管理

## 1. 概要

3つの機能を実装し、面接セッションのライフサイクルを完全に管理できるようにした。

| 機能 | 説明 |
|------|------|
| URL即時開始 | トークンベース認証により、Deviseログイン不要で面接を開始可能 |
| セッションタイムアウト | 一定時間操作がない面接を自動的にabandon状態に遷移 |
| 中断復帰 | abandoned状態の面接を再開し、中断した箇所から続行 |

---

## 2. DB変更（マイグレーション）

**ファイル:** `db/migrate/20260308120000_add_session_management_to_interviews.rb`

### interviews テーブル

| カラム | 型 | デフォルト | 説明 |
|--------|-----|----------|------|
| `access_token` | string | null | URL即時開始用トークン（UNIQUE INDEX） |
| `last_activity_at` | datetime | null | 最終操作時刻 |
| `resumed_at` | datetime | null | 最終復帰時刻 |
| `resume_count` | integer | 0 | 復帰回数 |

### situations テーブル

| カラム | 型 | デフォルト | 説明 |
|--------|-----|----------|------|
| `session_timeout_minutes` | integer | 60 | セッションタイムアウト（分） |
| `allow_resume` | boolean | true | 中断復帰を許可するか |
| `max_resume_count` | integer | 3 | 最大復帰回数 |

**後方互換**: 既存データはデフォルト値が適用され、既存の面接フローに影響なし。

---

## 3. URL即時開始（トークンベース認証）

### トークン生成

```ruby
# Interview 作成時に自動生成（before_create）
SecureRandom.urlsafe_base64(32)  # 43文字のURL-safeトークン
```

### 認証フロー

```
リクエスト受信
    │
    ├─ X-Interview-Token ヘッダー or access_token パラメータ
    │     └─ トークンで Interview 検索 → 成功 → @current_user = interview.user
    │
    ├─ テストモード（開発環境のみ）
    │     └─ テストユーザーで自動認証
    │
    └─ Devise認証にフォールバック
          └─ authenticate_user! → current_user
```

### 新エンドポイント

| メソッド | パス | 認証 | 説明 |
|---------|------|------|------|
| POST | `/api/interviews/start_by_token` | トークンのみ | URL即時開始/自動復帰 |

### レスポンス例

```json
{
  "success": true,
  "interview_id": 42,
  "status": "in_progress",
  "total_questions": 10,
  "language": "ja",
  "progress": 30.0,
  "answered_questions": 3,
  "session_timeout_minutes": 60,
  "remaining_seconds": 3420,
  "resume_count": 0
}
```

### 運用想定

1. Client が Situation を作成
2. `POST /api/interviews/start` でInterviewを作成（`access_token` が返却される）
3. 受験者に `https://example.com/interview?token=XXXXX` のURLを送付
4. フロントエンドが `start_by_token` を呼び出し、認証不要で面接開始

---

## 4. セッションタイムアウト

### 設計

| 項目 | 内容 |
|------|------|
| タイムアウト基準 | `last_activity_at` からの経過時間（アイドルタイムアウト方式） |
| 設定単位 | Situation単位（Client が設定可能、1-180分） |
| チェックタイミング | `next_question` / `submit_answer` の before_action |
| タイムアウト時の遷移 | `in_progress` → `abandoned`（410 Gone レスポンス） |

### タイムアウト判定

```ruby
def timed_out?
  return false unless in_progress? && last_activity_at.present?
  timeout = situation.session_timeout_minutes.minutes
  last_activity_at < timeout.ago
end
```

### アクティビティ更新

以下の操作時に `last_activity_at` を更新:

- `start!`（面接開始）
- `next_question`（質問取得）
- `submit_answer`（回答送信）
- `resume!`（面接再開）
- `start_by_token`（トークン認証開始）

### タイムアウト時のAPIレスポンス

```json
{
  "success": false,
  "error": "Interview session has timed out",
  "reason": "timeout",
  "resumable": true
}
```

### バッチ処理（一括期限切れ）

```ruby
# Sidekiq cronやRakeタスクから呼び出し
InterviewEngine::SessionManager.expire_timed_out_sessions!
```

---

## 5. 中断復帰

### 復帰可能条件

```ruby
def resumable?
  (abandoned? || (in_progress? && timed_out?)) &&
    situation.allow_resume? &&
    resume_count < situation.max_resume_count
end
```

### 復帰フロー

```
abandoned 面接
    │
    ├─ allow_resume? → false → "Interview cannot be resumed"
    │
    ├─ resume_count >= max_resume_count → "max retries exceeded"
    │
    └─ 復帰可能
         └─ status: in_progress
            resumed_at: 現在時刻
            last_activity_at: 現在時刻
            resume_count: +1
            ended_at: nil（リセット）
```

### 新エンドポイント

| メソッド | パス | 認証 | 説明 |
|---------|------|------|------|
| POST | `/api/interviews/:id/resume` | トークン or Devise | 中断面接の再開 |

### 自動復帰パス

以下のケースでは明示的な `resume` 呼び出し不要:

1. **`start_interview`**: abandoned面接が存在 & resumable → 自動resume
2. **`start_interview`**: in_progress面接が存在 → touch_activity して返却
3. **`start_by_token`**: abandoned面接のトークン → 自動resume

---

## 6. 状態遷移バリデーション

不正な状態遷移をモデルレベルで防止する。

### 許可される遷移

```
not_started ──→ in_progress
in_progress ──→ completed / failed / abandoned
abandoned   ──→ in_progress（復帰）
completed   ──→ （遷移不可）
failed      ──→ （遷移不可）
```

### 実装

```ruby
VALID_TRANSITIONS = {
  not_started: [:in_progress],
  in_progress: [:completed, :failed, :abandoned],
  abandoned:   [:in_progress],
  completed:   [],
  failed:      []
}.freeze

validate :valid_status_transition, if: :status_changed?
```

---

## 7. APIレスポンスへの追加フィールド

既存エンドポイントのレスポンスに以下のフィールドが追加された:

| フィールド | 型 | 含まれるエンドポイント | 説明 |
|-----------|-----|---------------------|------|
| `access_token` | string | start | 面接トークン |
| `session_timeout_minutes` | integer | start, start_by_token | タイムアウト設定 |
| `remaining_seconds` | integer | start, start_by_token, next_question, submit_answer | 残り時間（秒） |
| `resume_count` | integer | start_by_token, resume, status | 復帰回数 |
| `resumable` | boolean | status, timeout応答 | 復帰可能フラグ |

---

## 8. セキュリティ対策

| 対策 | 内容 |
|------|------|
| トークン強度 | `SecureRandom.urlsafe_base64(32)` — 256bit entropy |
| トークン一意性 | DB UNIQUE INDEX + ループ生成で衝突回避 |
| 認可統合 | トークン認証 → Devise認証のフォールバック（どちらかで認可） |
| テストモード保護 | `Rails.env.production?` でテストモードの本番有効化を防止 |
| 認可チェック強化 | `@current_user` + `user_id` 比較 + nil ガード |
| レースコンディション | DB UNIQUE制約 + `RecordNotUnique` 捕捉（409 Conflict） |
| 状態遷移保護 | `VALID_TRANSITIONS` バリデーションで不正遷移を防止 |

---

## 9. コードレビュー結果

Day 6のレビューで検出・修正した主要な指摘:

| 重要度 | 件数 | 主な内容 |
|--------|------|---------|
| Critical | 4 | SQLite固有スコープ、認可バイパス、二重DB検索、レート制限欠如 |
| Warning | 8 | レースコンディション、テストモード漏洩、状態遷移バリデーション、ロジック重複 |
| Info | 4 | マイグレーションバージョン、タイムアウト基準確認、CSRF保護範囲 |

---

## 10. 変更ファイル一覧

| ファイル | 種別 | 内容 |
|---------|------|------|
| `db/migrate/20260308120000_add_session_management_to_interviews.rb` | **新規** | access_token, last_activity_at, resumed_at, resume_count + Situation設定 |
| `app/models/interview.rb` | **改修** | トークン生成、タイムアウト判定、中断復帰、状態遷移バリデーション |
| `app/models/situation.rb` | **改修** | セッション設定バリデーション |
| `app/services/interview_engine/session_manager.rb` | **改修** | トークン認証開始、復帰ロジック、タイムアウト一括処理 |
| `app/controllers/api/interviews_controller.rb` | **改修** | 統合認証、新エンドポイント、タイムアウトチェック、セキュリティ修正 |
| `config/routes.rb` | **改修** | `start_by_token`, `resume` ルート追加 |

---

## 付録: 全APIエンドポイント一覧（Day 6時点）

| メソッド | パス | 認証 | 概要 |
|---------|------|------|------|
| POST | `/api/interviews/start` | Devise/Token | 面接開始（既存面接の自動復帰対応） |
| POST | `/api/interviews/start_by_token` | Token のみ | URL即時開始/自動復帰 |
| GET | `/api/interviews/:id/next_question` | Devise/Token | 次の質問取得（タイムアウトチェック付き） |
| POST | `/api/interviews/:id/submit_answer` | Devise/Token | 回答送信（タイムアウトチェック付き） |
| POST | `/api/interviews/:id/complete` | Devise/Token | 面接完了 |
| GET | `/api/interviews/:id/status` | Devise/Token | 状態取得（remaining_seconds, resumable含む） |
| POST | `/api/interviews/:id/resume` | Devise/Token | 中断面接の再開 |

---

*2026-03-08 時点 / master ブランチ*
