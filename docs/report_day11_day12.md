# AI面接インタビューシステム — Day 11・Day 12 報告書

**プロジェクト:** AI面接インタビューシステム
**フェーズ:** Phase 3（API堅牢化・Rails統合・データ保存改善）
**対象日:** Day 11・Day 12
**作成日:** 2026-03-16
**フレームワーク:** Ruby on Rails 6.1.7 / Ruby 3.1.6

---

## 目次

### Day 11: RSpecテスト基盤導入
1. テストフレームワーク導入
2. Factory定義（7ファイル）
3. モデルスペック（5ファイル）
4. リクエストスペック（1ファイル）
5. テスト数サマリー

### Day 12: ハードコード値の環境変数化
6. 設定管理イニシャライザ
7. サービスクラスの環境変数化
8. 設定値一覧
9. 設計判断

---

## Day 11: RSpecテスト基盤導入

### 1. テストフレームワーク導入

既存のMinitest空ファイル（test/ディレクトリ）に代わり、RSpecベースのテスト基盤を構築した。

#### 追加Gem

| Gem | バージョン | 用途 |
|-----|-----------|------|
| `rspec-rails` | ~> 5.1 | Rails対応RSpec |
| `factory_bot_rails` | ~> 6.2 | テストデータ生成 |
| `shoulda-matchers` | ~> 5.0 | バリデーション簡潔テスト |
| `database_cleaner-active_record` | ~> 2.1 | テストDB状態管理 |

#### 設定ファイル

| ファイル | 内容 |
|---------|------|
| `.rspec` | デフォルトオプション（documentation形式、カラー表示） |
| `spec/spec_helper.rb` | RSpec基本設定（モンキーパッチ無効化、ランダム順序） |
| `spec/rails_helper.rb` | Rails統合設定（FactoryBot、Shoulda、Devise統合） |

### 2. Factory定義（7ファイル）

| Factory | トレイト | 用途 |
|---------|---------|------|
| `users` | — | テストユーザー（Devise対応） |
| `clients` | — | テストクライアント（Devise対応） |
| `situations` | `:with_questions`, `:no_resume`, `:short_timeout` | 面接シナリオ |
| `questions` | `:multiple_choice`, `:with_branching`, `:optional` | 質問 |
| `interviews` | `:in_progress`, `:completed`, `:failed`, `:abandoned`, `:timed_out`, `:rejected` | 面接セッション |
| `interview_responses` | `:evaluated`, `:failed_evaluation` | 回答・評価データ |
| `interview_results` | `:failed`, `:with_rejection` | 面接結果 |

### 3. モデルスペック（5ファイル）

#### Interview（interview_spec.rb）
- アソシエーション: user, situation, interview_responses, interview_result
- バリデーション: presence（user_id, situation_id, language）、uniqueness（user_id+situation_id）
- ステータス遷移: 正常遷移（start!, complete!, fail!, abandon!）、不正遷移の拒否
- ビジネスロジック: timed_out?, resumable?, resume!, rejected?, duration, progress_percentage
- カスタムバリデーション: ensure_situation_has_questions, ensure_no_previous_interview
- access_token: 自動生成・ユニーク性

#### InterviewResponse（interview_response_spec.rb）
- evaluation_data: score, passed_evaluation?, evaluated?
- storeアクセサ: relevance_score, correctness_score, clarity_score, evaluation_feedback

#### Question（question_spec.rb）
- 型判定: multiple_choice? (choice/multiple_choice/mcq), descriptive?
- 分岐ルール: has_branching_rules?, parsed_branching_rules
- オプション: parsed_options、options_required_for_multiple_choice
- スコープ: ordered

#### InterviewResult（interview_result_spec.rb）
- completion_percentage: 正常計算、ゼロ除算防止、nil安全性
- rejected?: rejection_details判定
- ユニーク制約: 同一interview_idの重複防止

#### Situation（situation_spec.rb）
- numericality: session_timeout_minutes, max_resume_count, passing_score
- inclusion: reject_notify_method
- スコープ: active（非アーカイブ）

### 4. リクエストスペック（1ファイル）

#### Api::Interviews（requests/api/interviews_spec.rb）

| エンドポイント | テスト内容 |
|-------------|-----------|
| POST /api/interviews/start | 正常開始、存在しないsituation |
| GET /api/interviews/:id/status | ステータス取得 |
| POST /api/interviews/:id/submit_answer | パラメータ不足エラー |
| POST /api/interviews/:id/complete | 非in_progress状態エラー |
| 認証 | 無効トークンの拒否 |
| Content-Type | 未対応Content-Typeの拒否 |

### 5. テスト数サマリー

| カテゴリ | ファイル数 | テストケース数 |
|---------|-----------|--------------|
| モデルスペック | 5 | 約50 |
| リクエストスペック | 1 | 7 |
| **合計** | **6** | **約57** |

---

## Day 12: ハードコード値の環境変数化

### 6. 設定管理イニシャライザ

`config/initializers/interview_config.rb` を新規作成し、全27項目の設定値を `Rails.application.config.interview` に集約。

| カテゴリ | 項目数 | 環境変数例 |
|---------|--------|-----------|
| LLM設定 | 7 | `OPENAI_MODEL`, `LLM_TEMPERATURE`, `LLM_MAX_TOKENS` |
| STT設定 | 4 | `STT_MODEL`, `STT_TIMEOUT`, `STT_MAX_FILE_SIZE_MB` |
| TTS設定 | 7 | `TTS_MODEL`, `TTS_DEFAULT_VOICE`, `TTS_VOICE_JA` |
| メディア処理 | 5 | `MAX_VIDEO_SIZE_MB`, `FFMPEG_TIMEOUT`, `MAX_AUDIO_DURATION` |
| 評価設定 | 4 | `DEFAULT_PASS_THRESHOLD`, `EVAL_WEIGHT_RELEVANCE` |

### 7. サービスクラスの環境変数化

| ファイル | 変更内容 |
|---------|---------|
| `llm_client.rb` | MAX_RETRIES, REQUEST_TIMEOUT, model名, temperature, max_tokens → config参照 |
| `stt_client.rb` | MAX_FILE_SIZE, MAX_RETRIES, TIMEOUT_SECONDS, model名 → config参照 |
| `tts_client.rb` | MAX_TEXT_LENGTH, MAX_RETRIES, TIMEOUT_SECONDS, model名, VOICE_MAP → config参照 |
| `media_processor.rb` | MAX_VIDEO_SIZE, FFMPEG_TIMEOUT, MIN/MAX_AUDIO_DURATION → config参照 |
| `response_evaluator.rb` | DEFAULT_PASS_THRESHOLD, 評価重み → config参照 |
| `file_upload_validation.rb` | MAX_AUDIO_SIZE, MAX_VIDEO_SIZE → config参照 |
| `.env.example` | 27項目の環境変数テンプレート追加 |

### 8. 設定値一覧

#### LLM 設定
```
LLM_MODEL=openai                # openai / claude
OPENAI_MODEL=gpt-4              # OpenAI 評価モデル
CLAUDE_MODEL=claude-sonnet-4-20250514
LLM_TEMPERATURE=0.2             # 評価の再現性重視
LLM_MAX_TOKENS=600
LLM_MAX_RETRIES=3
LLM_REQUEST_TIMEOUT=30          # 秒
```

#### STT (Speech-to-Text)
```
STT_MODEL=whisper-1
STT_MAX_FILE_SIZE_MB=25          # Whisper API上限
STT_MAX_RETRIES=2
STT_TIMEOUT=60                   # 秒
```

#### TTS (Text-to-Speech)
```
TTS_MODEL=tts-1
TTS_MAX_TEXT_LENGTH=4096
TTS_DEFAULT_VOICE=nova
TTS_VOICE_JA=nova
TTS_VOICE_EN=nova
```

#### メディア処理
```
MAX_VIDEO_SIZE_MB=500
MAX_AUDIO_SIZE_MB=25
FFMPEG_TIMEOUT=120               # 秒
MIN_AUDIO_DURATION=0.5           # 秒
MAX_AUDIO_DURATION=600           # 秒（10分）
```

#### 評価設定
```
DEFAULT_PASS_THRESHOLD=70        # デフォルト合格ライン
EVAL_WEIGHT_RELEVANCE=0.4       # 関連性 40%
EVAL_WEIGHT_CORRECTNESS=0.4     # 正確性 40%
EVAL_WEIGHT_CLARITY=0.2         # 明瞭性 20%
```

### 9. 設計判断

#### 一元管理パターン
各サービスクラスで直接 `ENV.fetch` するのではなく、イニシャライザで一括パースし `Rails.application.config.interview` 経由でアクセスする方式を採用。

- 設定値の全体像が一目で分かる
- 型変換（`.to_i`, `.to_f`）がイニシャライザ内で完結
- テスト時に `Rails.application.config.interview.xxx = ...` で容易にオーバーライド可能

#### 後方互換性の保証
全項目にデフォルト値を設定。環境変数を一切設定しなくても既存動作と完全に同一。

#### API URL は定数のまま
`OPENAI_URL`, `CLAUDE_URL` 等のAPIエンドポイントURLはサービス仕様として固定であり、定数のまま残している。

---

## Day 11・12 変更ファイル一覧

### 新規作成ファイル

| ファイル | 内容 |
|---------|------|
| `.rspec` | RSpecデフォルト設定 |
| `spec/spec_helper.rb` | RSpec基本設定 |
| `spec/rails_helper.rb` | Rails統合設定 |
| `spec/factories/users.rb` | Userファクトリ |
| `spec/factories/clients.rb` | Clientファクトリ |
| `spec/factories/situations.rb` | Situationファクトリ |
| `spec/factories/questions.rb` | Questionファクトリ |
| `spec/factories/interviews.rb` | Interviewファクトリ |
| `spec/factories/interview_responses.rb` | InterviewResponseファクトリ |
| `spec/factories/interview_results.rb` | InterviewResultファクトリ |
| `spec/models/interview_spec.rb` | Interviewモデルスペック |
| `spec/models/interview_response_spec.rb` | InterviewResponseモデルスペック |
| `spec/models/question_spec.rb` | Questionモデルスペック |
| `spec/models/interview_result_spec.rb` | InterviewResultモデルスペック |
| `spec/models/situation_spec.rb` | Situationモデルスペック |
| `spec/requests/api/interviews_spec.rb` | APIリクエストスペック |
| `config/initializers/interview_config.rb` | 設定値一元管理 |

### 修正ファイル

| ファイル | 変更内容 |
|---------|---------|
| `Gemfile` | rspec-rails, factory_bot_rails, shoulda-matchers, database_cleaner追加 |
| `app/services/interview_engine/llm_client.rb` | ハードコード値 → config参照 |
| `app/services/interview_engine/stt_client.rb` | ハードコード値 → config参照 |
| `app/services/interview_engine/tts_client.rb` | ハードコード値 → config参照 |
| `app/services/interview_engine/media_processor.rb` | ハードコード値 → config参照 |
| `app/services/interview_engine/response_evaluator.rb` | ハードコード値 → config参照 |
| `app/controllers/concerns/file_upload_validation.rb` | ハードコード値 → config参照 |
| `.env.example` | 27項目の環境変数テンプレート追加 |

---

## セットアップ手順

```bash
# 1. Gem インストール
bundle install

# 2. テスト用DB作成・マイグレーション
RAILS_ENV=test bundle exec rails db:create db:migrate

# 3. テスト実行
bundle exec rspec

# 4. 特定ファイル実行
bundle exec rspec spec/models/interview_spec.rb
```

## 次のステップ（Day 13）

- 最終整備（ドキュメント整理、残課題の棚卸し）
- Phase 3 完了レビュー
