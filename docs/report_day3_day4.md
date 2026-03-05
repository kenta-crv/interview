# AI面接インタビューシステム — Day 3・Day 4 報告書

**作成日:** 2026-03-06 | **リポジトリ:** tianzhongyoushi178/AI_Interviewer | **ブランチ:** master

---

## 目次

- [Day 3: 技術仕様・API設計書の策定](#day-3-技術仕様api設計書の策定)
- [Day 4: 質問分岐エンジンの構築](#day-4-質問分岐エンジンの構築)

---

# Day 3: 技術仕様・API設計書の策定

## 1. LLM制御方針

### 基本原則

LLMの出力を**構造化JSON**に限定し、自由文生成によるハルシネーションリスクを排除する。

| 制御項目 | 方針 |
|---------|------|
| 出力形式 | JSON Only — `Return ONLY valid JSON` を明示 |
| Temperature | 0.3（評価）/ 0.4（記事生成） |
| Max Tokens | 500（評価・要約） |
| System Prompt | 役割限定 + 会話禁止ルール |
| レスポンス検証 | JSONパース → 正規表現抽出 → デフォルトエラーレスポンス |

### プロンプトテンプレート

| テンプレート | 用途 | 出力スキーマ |
|------------|------|-------------|
| 回答評価 | 個別回答のスコアリング | `{relevance_score, correctness_score, clarity_score, final_score, passed, reasoning}` |
| 面接要約 | 面接完了後の総合フィードバック | `{summary, strengths[], weaknesses[], recommendation}` |
| MCQ評価 | 選択式の即時判定 | LLM不使用 — 正解一致→100 / 不正解→0 |

### バリデーション・フォールバック

```
LLMレスポンス → JSONパース → 成功 → 必須キー確認 → 使用
                            → 失敗 → 正規表現でJSON抽出 → 再パース
                                                        → 失敗 → デフォルトエラーレスポンス
```

---

## 2. 外部API一覧

| # | API | 用途 | 現在モデル | 推奨モデル | コスト効果 |
|---|-----|------|-----------|-----------|-----------|
| 1 | OpenAI Chat | 回答評価 | gpt-4 | **gpt-4o-mini** | コスト1/200 |
| 2 | OpenAI Chat | 面接要約 | gpt-4 | **gpt-4o** | コスト1/12 |
| 3 | Anthropic Messages | 評価（代替） | claude-3-sonnet | claude-3.5-haiku | — |
| 4 | OpenAI Whisper | 音声→テキスト | whisper-1 | 現状維持 | $0.006/分 |
| 5 | OpenAI TTS | テキスト→音声 | tts-1 | 現状維持 | $15/100万字 |
| 6 | OpenAI Chat | 記事本文生成 | gpt-4o-mini | 現状維持 | — |
| 7 | Google Gemini | 記事メタ生成 | gemini-2.0-flash | 現状維持 | — |
| 8 | ffmpeg（ローカル） | 動画→音声抽出 | — | 現状維持 | 無料 |

### 月額コスト比較（100面接/月）

| 項目 | 現在 | 推奨後 |
|------|------|--------|
| API合計 | ~$65/月 | **~$5.33/月**（92%削減） |

---

## 3. DB設計書（ER図）最終版

### ER構造

```
Admin

Client ──1:N── Situation ──1:N── Question ──1:N── QuestionAudio
                    │
                    └──1:N── Interview (User+Situation=UNIQUE)
                                ├──1:N── InterviewResponse
                                └──1:1── InterviewResult

User ──1:N── Interview
```

### テーブル数: 16テーブル

- 認証系: admins, clients, users（Devise 3モデル）
- 面接系: situations, questions, question_audios, interviews, interview_responses, interview_results
- コンテンツ系: columns, contracts, friendly_id_slugs, active_storage_blobs/attachments
- レガシー: answers（削除予定）

### 推奨スキーマ変更

| 対象 | 追加内容 |
|------|---------|
| カラム | situations に `min_score_required`, `fail_policy` / questions に `time_limit_seconds`, `difficulty_level` |
| インデックス | interviews(status,created_at), questions(situation_id,order), situations(client_id,archived) |
| FK制約 | situations→clients, answers→users |

---

## 4. 内部API設計書

| メソッド | パス | 機能 | 主なエラー |
|---------|------|------|-----------|
| POST | /api/interviews/start | 面接開始 | 422: バリデーション失敗 |
| GET | /api/interviews/:id/next_question | 次の質問取得 | — |
| POST | /api/interviews/:id/submit_answer | 回答送信 | 400: 回答なし/重複/STT失敗 |
| POST | /api/interviews/:id/complete | 面接完了 | 400: 未評価回答あり |
| GET | /api/interviews/:id/status | 状態取得 | — |

**認証**: Devise セッションCookie / テストモード時は `test@interview.com` で自動認証
**非同期ジョブ**: `EvaluateInterviewResponseJob`（回答評価）/ `GenerateColumnBodyJob`（記事生成）

---

# Day 4: 質問分岐エンジンの構築

## 1. 概要

従来の線形出題（order 昇順で全問出題）を拡張し、**前の回答に応じた動的な質問選択**を実現する分岐エンジンを構築した。

### 追加機能

| 機能 | 説明 |
|------|------|
| 必須/任意フラグ | 質問ごとに `required` を設定。任意質問は低スコアでも面接を fail にしない |
| カテゴリ分類 | 質問を「技術」「コミュニケーション」等のカテゴリで分類 |
| 分岐ルール | JSON形式で条件付き出題ルールを定義。条件不一致の質問を自動スキップ |

---

## 2. DB変更（マイグレーション）

**ファイル:** `db/migrate/20260306120000_add_branching_to_questions.rb`

| カラム | 型 | デフォルト | 説明 |
|--------|-----|----------|------|
| required | boolean | true | 必須質問フラグ |
| category | string | null | 質問カテゴリ |
| branching_rules | json | null | 分岐条件（JSON） |

**後方互換**: 既存の質問は `required=true`, `branching_rules=null` となり、従来通り無条件で出題される。

---

## 3. 分岐ルールのJSON構造

```json
{
  "conditions": [
    {
      "source_question_order": 1,
      "type": "selected_option",
      "value": "Python",
      "action": "include"
    }
  ],
  "default_action": "skip"
}
```

### 条件タイプ

| type | 説明 | 判定方法 |
|------|------|---------|
| `selected_option` | MCQ回答の選択肢一致 | 回答テキスト == value（大文字小文字無視） |
| `score_above` | スコアが指定値以上 | final_score >= value |
| `score_below` | スコアが指定値未満 | final_score < value |
| `answered` | 回答済みかどうか | InterviewResponse が存在 |

### アクション

| action | 説明 |
|--------|------|
| `include` | 条件一致時に出題する |
| `skip` | 条件一致時にスキップする |

### 評価フロー

```
質問の branching_rules を確認
    │
    ├─ null → 無条件で出題（従来動作）
    │
    └─ あり → conditions を順に評価
                │
                ├─ 条件一致 → action に従い include/skip
                │
                └─ 全条件不一致 → default_action に従う
```

---

## 4. 変更ファイル一覧

### 4.1 Question モデル（`app/models/question.rb`）

**追加内容:**

| 種別 | 名前 | 説明 |
|------|------|------|
| scope | `required_only` | 必須質問のみ取得 |
| メソッド | `has_branching_rules?` | 分岐ルールの有無を判定 |
| メソッド | `parsed_branching_rules` | JSONを安全にパースしてシンボルキーで返却 |

### 4.2 QuestionSelector（`app/services/interview_engine/question_selector.rb`）

**変更内容:**

| メソッド | 変更 |
|---------|------|
| `get_next_question` | `unanswered_questions` → `eligible_questions` に変更 |
| `should_continue_interview?` | 同上 |
| `prepare_question_audio` | `required` フィールド追加、`total_questions` を出題対象数に変更 |
| `get_question_text` | 同上 |

**追加メソッド:**

| メソッド | 説明 |
|---------|------|
| `eligible_questions` | 未回答 + 分岐条件を満たす質問を抽出 |
| `total_eligible_count` | 回答済み + 出題対象の合計数 |
| `evaluate_branching_rules(question)` | 質問の分岐ルール全体を評価 |
| `evaluate_condition(condition)` | 個別条件を評価（type別の判定） |
| `find_response_for_question_order(order)` | order番号から InterviewResponse を検索 |

### 4.3 ResponseEvaluator（`app/services/interview_engine/response_evaluator.rb`）

**変更内容:**

`check_interview_continuation` メソッドに `return unless @question.required?` を追加。
任意質問（`required: false`）で低スコアでも面接全体を fail にしない。

### 4.4 QuestionsController（`app/controllers/questions_controller.rb`）

**変更内容:**

- strong params に `:required`, `:category`, `:branching_rules` を追加
- `parse_branching_rules_json` メソッド追加（フォーム入力のJSON文字列をパース）

### 4.5 質問フォーム（`app/views/questions/_form.html.slim`）

**追加フィールド:**

| フィールド | UI部品 | 説明 |
|-----------|--------|------|
| 必須質問 | チェックボックス | デフォルトON |
| カテゴリ | テキストフィールド | 自由入力 |
| 分岐ルール | テキストエリア（JSON） | サンプルJSON表示 + 入力ガイド |

---

## 5. 分岐ルールの使用例

### 例1: MCQ回答による分岐

質問1「使用言語は？」→ 「Python」選択時のみ質問3を出題

```json
// 質問3の branching_rules
{
  "conditions": [
    {"source_question_order": 1, "type": "selected_option", "value": "Python", "action": "include"}
  ],
  "default_action": "skip"
}
```

### 例2: スコアによる追加質問

質問2のスコアが50未満の場合、補足質問4を出題

```json
// 質問4の branching_rules
{
  "conditions": [
    {"source_question_order": 2, "type": "score_below", "value": 50, "action": "include"}
  ],
  "default_action": "skip"
}
```

### 例3: 高スコア時のみ上級質問を出題

質問1のスコアが90以上の場合のみ出題

```json
// 上級質問の branching_rules
{
  "conditions": [
    {"source_question_order": 1, "type": "score_above", "value": 90, "action": "include"}
  ],
  "default_action": "skip"
}
```

---

## 6. 後方互換性

| 項目 | 既存データへの影響 |
|------|------------------|
| `branching_rules = null` | 従来通り無条件で出題 |
| `required = true`（デフォルト） | 既存質問は全て必須扱い（挙動変更なし） |
| `category = null` | 動作に影響なし |
| APIレスポンス | `required` フィールドが追加されるのみ |

---

## 付録: Day 3・4 成果物一覧

| ファイル | 種別 | 内容 |
|---------|------|------|
| `docs/day3_technical_spec.md` | ドキュメント | 技術仕様・API設計書（詳細版） |
| `db/migrate/20260306120000_add_branching_to_questions.rb` | マイグレーション | questions テーブル拡張 |
| `app/models/question.rb` | モデル | スコープ・メソッド追加 |
| `app/services/interview_engine/question_selector.rb` | サービス | 分岐エンジン実装 |
| `app/services/interview_engine/response_evaluator.rb` | サービス | 任意質問の即fail防止 |
| `app/controllers/questions_controller.rb` | コントローラ | strong params更新 |
| `app/views/questions/_form.html.slim` | ビュー | 管理画面フォーム拡張 |

---

*2026-03-06 時点 / master ブランチ*
