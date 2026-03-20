# AI面接インタビューシステム — Day 14 報告書

**プロジェクト:** AI面接インタビューシステム
**フェーズ:** Phase 4（テストカバレッジ拡充）— Service層テスト導入
**対象日:** Day 14
**作成日:** 2026-03-18
**フレームワーク:** Ruby on Rails 6.1.7 / Ruby 3.1.6

---

## 目次

### Day 14: Service層テスト導入・API統合テスト拡充
1. 概要
2. テスト基盤の改善
3. SessionManager テスト（25テスト）
4. ResponseEvaluator テスト（12テスト）
5. QuestionSelector テスト（16テスト）
6. RejectJudge テスト（16テスト）
7. LLMClient テスト（10テスト）
8. STTClient テスト（11テスト）
9. TTSClient テスト（11テスト）
10. ResponseValidator テスト（13テスト）
11. PromptTemplate テスト（10テスト）
12. API統合テスト拡充（+24テスト）
13. テスト結果サマリー
14. 変更ファイル一覧

---

# Day 14 — Service層テスト導入・API統合テスト拡充

## 1. 概要

Phase 4の初日として、**Service層のテスト完全導入**と**API統合テストの大幅拡充**を実施した。Day 13時点でService層テストカバレッジが0%だった状態から、主要9サービスすべてにRSpecテストを追加。API統合テストも7テスト→31テストに拡充。テスト総数は96→254（+158テスト、2.6倍）となり、全件パスを確認した。

---

## 2. テスト基盤の改善

### `spec/rails_helper.rb` への追加

`ActiveSupport::Testing::TimeHelpers` をRSpec全体に追加し、`travel_to`・`freeze_time` 等のタイムトラベルヘルパーを全テストで利用可能にした。

```ruby
config.include ActiveSupport::Testing::TimeHelpers
```

**理由:** SessionManagerのタイムアウトテスト等で時間操作が必要なため。

---

## 3. SessionManager テスト（25テスト）

**ファイル:** `spec/services/interview_engine/session_manager_spec.rb`

### テスト対象メソッド

| メソッド | テスト数 | 内容 |
|---------|---------|------|
| `#start_interview` | 7 | 新規開始、言語指定、既存in_progress復帰、完了済みエラー、失敗済みエラー、abandoned復帰、トークン生成 |
| `.start_by_token` | 7 | 有効トークン、無効トークン、アクティビティ更新、完了済みエラー、タイムアウト、abandoned復帰、resume上限 |
| `#resume_interview` | 4 | 正常再開、非resumableエラー、resume上限、allow_resume=false |
| `#touch_session` | 2 | 正常更新、タイムアウト |
| `#check_timeout!` | 3 | 正常、タイムアウト+abandon、非in_progress |
| `#get_interview_state` | 1 | 状態ハッシュの検証 |
| `#fail_interview` | 2 | 失敗+InterviewResult作成、既存Result返却 |
| `#complete_interview` | 2 | pending回答エラー、正常完了+LLMモック |
| `.expire_timed_out_sessions!` | 1 | 一括abandon |

---

## 4. ResponseEvaluator テスト（12テスト）

**ファイル:** `spec/services/interview_engine/response_evaluator_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| テストモード | 1 | 固定スコアでの評価 |
| LLM評価 | 4 | 結果保存、加重平均再計算、合格判定、不合格判定 |
| 選択式問題 | 3 | 正解/不正解、大文字小文字無視 |
| エラーハンドリング | 2 | 空transcript、LLM失敗時のfailedステータス |
| リジェクション | 1 | RejectJudge呼び出し確認 |

### 設計ポイント

- LLMの`final_score`を無視し、加重平均（relevance 40% + correctness 40% + clarity 20%）で再計算することをテストで検証
- `evaluate_multiple_choice`は外部API不要で完全にローカル処理

---

## 5. QuestionSelector テスト（16テスト）

**ファイル:** `spec/services/interview_engine/question_selector_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| `#get_next_question` | 4 | 未回答の最初を返す、order順、回答済みスキップ、全問完了エラー |
| `#should_continue_interview?` | 2 | 未回答あり/全問完了 |
| `#get_question_text` | 2 | テキスト返却、選択式options含む |
| 分岐ルール: selected_option | 2 | 条件一致で含む/除外 |
| 分岐ルール: score_above | 2 | スコア基準以上で含む/除外 |
| 分岐ルール: score_below | 1 | スコア基準未満で含む |
| 分岐ルール: answered | 2 | 回答済みで含む/除外 |
| 分岐ルールなし | 1 | 常に含まれる |

---

## 6. RejectJudge テスト（16テスト）

**ファイル:** `spec/services/interview_engine/reject_judge_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| `#judge_after_response` | 8 | auto_reject無効、必須質問不合格、基準以上通過、reject_on_required_fail=false、オプション質問、連続不合格、カウントリセット、max=0 |
| `#judge_on_completion` | 4 | auto_reject無効、平均スコア未達、平均スコア通過、スコア空 |
| `#apply_rejection!` | 3 | 正常適用、非リジェクト、非in_progress |
| `RejectDecision` | 1 | rejected?フラグ検証 |

---

## 7. LLMClient テスト（10テスト）

**ファイル:** `spec/services/interview_engine/llm_client_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| OpenAI評価 | 5 | 正常レスポンス、APIキー未設定、タイムアウト、レート制限429、認証エラー401 |
| Claude評価 | 2 | 正常呼び出し、APIキー未設定 |
| 不明モデル | 1 | デフォルトエラー |
| サマリー | 2 | 正常サマリー、API失敗時デフォルト |

### モック方式

Net::HTTPの `instance_double` を使用し、外部API呼び出しを完全モック化。sleepもスタブ化してテスト速度を維持。

---

## 8. STTClient テスト（11テスト）

**ファイル:** `spec/services/interview_engine/stt_client_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| ファイルバリデーション | 4 | 存在しない、不正形式、空ファイル、サイズ超過 |
| API呼び出し | 4 | 正常トランスクリプト、空トランスクリプト、500エラー、400エラー |
| APIキー | 1 | 未設定 |
| 言語正規化 | 3 | ja/en/未知言語 |

---

## 9. TTSClient テスト（11テスト）

**ファイル:** `spec/services/interview_engine/tts_client_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| `#speak` | 8 | 正常音声生成、空テキスト、nilテキスト、APIキー未設定、429リトライ、500リトライ、400エラー、空音声レスポンス |
| 言語別ボイス | 3 | ja/en/未知言語 |

---

## 10. ResponseValidator テスト（13テスト）

**ファイル:** `spec/services/interview_engine/response_validator_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| `.extract_json` | 6 | 通常JSON、コードブロック、テキスト内JSON、空文字列、nil、無効JSON |
| `.validate_evaluation!` | 5 | 有効データ、必須キー欠損、非Hash、スコアクランプ、boolean変換 |
| `.validate_summary!` | 4 | 有効データ、必須キー欠損、配列制限、非配列変換 |

---

## 11. PromptTemplate テスト（10テスト）

**ファイル:** `spec/services/interview_engine/prompt_template_spec.rb`

### テスト対象

| カテゴリ | テスト数 | 内容 |
|---------|---------|------|
| `.evaluation` | 4 | 日本語/英語プロンプト、言語フォールバック、サニタイズ |
| `.summary` | 3 | 日本語/英語サマリー、空データエラー |
| `.expected_schema` | 3 | 評価/サマリースキーマ、不明タイプエラー |

---

## 12. API統合テスト拡充（+24テスト）

**ファイル:** `spec/requests/api/interviews_spec.rb`

### 追加テスト

| エンドポイント | 追加テスト数 | 追加内容 |
|-------------|-----------|---------|
| `POST /start` | +2 | remaining_seconds確認、重複start時の既存ID返却 |
| `POST /start_by_token` | +5 | 正常開始、access_token未指定、無効トークン、タイムアウト410、resume上限403 |
| `GET /status` | +2 | リジェクション情報、404 |
| `GET /next_question` | +4 | 正常取得（TTSモック）、全問完了、非in_progressエラー、タイムアウト410 |
| `POST /submit_answer` | +7 | テキスト回答成功、不正question_id、二重回答防止、入力なしエラー、Job enqueue、selected_option、タイムアウト |
| `POST /complete` | +2 | 正常完了（LLMモック）、pending回答エラー |
| `POST /resume` | +3 | 正常再開、非resumable、resume上限 |
| 認証 | +2 | 有効トークン（ヘッダー）、access_tokenパラメータ |
| Content-Type | +1 | application/json受入 |

---

## 13. テスト結果サマリー

### テスト数の推移

| 時点 | テスト数 | 増加 |
|------|---------|------|
| Day 11（テスト基盤導入） | 96 | — |
| Day 13（最終整備） | 96 | 0 |
| **Day 14（Service層テスト）** | **254** | **+158** |

### カバレッジ比較

| 対象 | Day 13 | Day 14 |
|------|--------|--------|
| Model層 | 5/13 (38%) | 5/13 (38%) |
| Service層 | **0/12 (0%)** | **9/12 (75%)** |
| API層 | 7テスト | **31テスト** |
| 全テスト | 96 | **254** |

### 未テストService（3件）

| Service | 理由 |
|---------|------|
| `AudioInterviewService` | MediaProcessor/STT統合テスト（ffmpeg依存） |
| `MediaProcessor` | ffmpegコマンド依存（実行環境制約） |
| `EvaluateInterviewResponseJob` | 非同期Job（Job enqueueのみAPI側で検証済み） |

### Service層テスト詳細

| Service | テスト数 | 状態 |
|---------|---------|------|
| SessionManager | 25 | 完了 |
| ResponseEvaluator | 12 | 完了 |
| QuestionSelector | 16 | 完了 |
| RejectJudge | 16 | 完了 |
| LLMClient | 10 | 完了 |
| STTClient | 11 | 完了 |
| TTSClient | 11 | 完了 |
| ResponseValidator | 13 | 完了 |
| PromptTemplate | 10 | 完了 |

---

## 14. 変更ファイル一覧

### 新規作成ファイル

| ファイル | 内容 |
|---------|------|
| `spec/services/interview_engine/session_manager_spec.rb` | SessionManager テスト（25テスト） |
| `spec/services/interview_engine/response_evaluator_spec.rb` | ResponseEvaluator テスト（12テスト） |
| `spec/services/interview_engine/question_selector_spec.rb` | QuestionSelector テスト（16テスト） |
| `spec/services/interview_engine/reject_judge_spec.rb` | RejectJudge テスト（16テスト） |
| `spec/services/interview_engine/llm_client_spec.rb` | LLMClient テスト（10テスト） |
| `spec/services/interview_engine/stt_client_spec.rb` | STTClient テスト（11テスト） |
| `spec/services/interview_engine/tts_client_spec.rb` | TTSClient テスト（11テスト） |
| `spec/services/interview_engine/response_validator_spec.rb` | ResponseValidator テスト（13テスト） |
| `spec/services/interview_engine/prompt_template_spec.rb` | PromptTemplate テスト（10テスト） |

### 修正ファイル

| ファイル | 変更内容 |
|---------|---------|
| `spec/rails_helper.rb` | `ActiveSupport::Testing::TimeHelpers` をインクルード |
| `spec/requests/api/interviews_spec.rb` | 7テスト→31テストに拡充（+24テスト） |

---

## セットアップ手順

```bash
# 1. Gem インストール（production除外）
bundle config set --local without production
bundle install

# 2. DB作成・マイグレーション
bundle exec rails db:create
bundle exec rails db:migrate

# 3. テスト用DB
RAILS_ENV=test bundle exec rails db:create db:migrate

# 4. テスト実行
bundle exec rspec

# 5. 詳細レポート
bundle exec rspec --format documentation
```

---

## 次のステップ（Day 15 候補）

| 項目 | 優先度 | 概要 |
|------|--------|------|
| AudioInterviewService/MediaProcessor テスト | 中 | ffmpegモック化によるテスト |
| EvaluateInterviewResponseJob テスト | 中 | Jobの単体テスト |
| N+1クエリ最適化 | 中 | Bulletの導入・include/eager_load |
| レート制限（Rack::Attack） | 中 | API保護強化 |
| Rails 7.0+ アップグレード | 低 | EOL対応 |
| メール通知機能 | 低 | ActionMailer統合 |

---

> **Day 14 完了:** Service層テスト9件導入 + API統合テスト拡充で、テスト数を96→254（+158、2.6倍）に増加。全254テストがパス。Service層カバレッジ0%→75%を達成。

---

*AI面接インタビューシステム — Day 14 報告書 | 2026-03-18 | master ブランチ*
