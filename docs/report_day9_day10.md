# AI面接インタビューシステム — Day 9・Day 10 報告書

**作成日:** 2026-03-15 | **リポジトリ:** tianzhongyoushi178/AI_Interviewer | **ブランチ:** master | **フレームワーク:** Rails 6.1.7 / Ruby 3.1.6

---

## 目次

**Day 9 — セキュリティ強化・DB改善・API品質統一・レガシー削除**
1. 概要
2. production.rb セキュリティ修正
3. APIキー起動時検証
4. APIエラーレスポンス統一（ApiErrorHandler）
5. ファイルアップロードバリデーション（FileUploadValidation）
6. Content-Type検証
7. レガシーAnswerテーブル削除
8. DBインデックス追加・FK制約追加
9. コントローラー改修まとめ
10. コードレビュー結果
11. 変更ファイル一覧

---

# Day 9 — セキュリティ強化・DB改善・API品質統一・レガシー削除

## 1. 概要

Day 1の現状分析で特定されたセキュリティ課題・パフォーマンス課題・保守性課題を一括修正した。本番環境向けのセキュリティ強化、API品質の統一、不要コードの削除を実施。

| カテゴリ | 対応内容 |
|---------|---------|
| **セキュリティ** | 本番エラー詳細露出の修正、SSL強制、ファイルアップロード検証、Content-Type検証、APIキー起動時チェック |
| **API品質** | エラーレスポンスの統一（ApiErrorHandler concern）、汎用rescueの排除 |
| **DB改善** | 4つの複合インデックス追加、FK制約追加（situations→clients） |
| **レガシー削除** | Answer テーブル・モデル・コントローラー・ビュー・ルーティングの完全削除 |

---

## 2. production.rb セキュリティ修正

**ファイル:** `config/environments/production.rb`

| 設定項目 | 修正前 | 修正後 | 理由 |
|---------|--------|--------|------|
| `consider_all_requests_local` | `true` | `false` | スタックトレースが本番で露出していた |
| `force_ssl` | コメントアウト | `true` | HTTPS未強制（中間者攻撃リスク） |
| `log_level` | `:debug` | `:info` | 本番ログ肥大化防止 |

---

## 3. APIキー起動時検証

**ファイル:** `config/initializers/api_key_validation.rb`（新規）

| 動作 | 説明 |
|------|------|
| 起動時チェック | `OPENAI_API_KEY` の存在を検証 |
| 開発環境 | 警告ログのみ（起動は続行） |
| 本番環境 | 未設定時は例外を発生させて起動を阻止 |
| テスト環境 | チェックをスキップ |

```ruby
Rails.application.config.after_initialize do
  next if Rails.env.test?
  required_keys = { 'OPENAI_API_KEY' => 'OpenAI (LLM評価/STT/TTS)' }
  missing = required_keys.select { |key, _| ENV[key].blank? }
  if missing.any? && Rails.env.production?
    raise "Missing required API keys: #{missing.keys.join(', ')}"
  end
end
```

---

## 4. APIエラーレスポンス統一（ApiErrorHandler）

**ファイル:** `app/controllers/concerns/api_error_handler.rb`（新規）

### 統一レスポンス形式

```json
{
  "success": false,
  "error": "エラーメッセージ",
  "reason": "オプション: エラーの種類",
  "details": { "オプション: 追加情報" }
}
```

### 自動ハンドリング

| 例外 | HTTPステータス | 説明 |
|------|--------------|------|
| `ActiveRecord::RecordNotFound` | 404 Not Found | リソース未発見 |
| `ActiveRecord::RecordInvalid` | 422 Unprocessable Entity | バリデーション失敗 |
| `ActiveRecord::RecordNotUnique` | 409 Conflict | 一意制約違反 |
| `ActionController::BadRequest` | 400 Bad Request | 不正なリクエスト |

### 改善点

- 各アクションの汎用 `rescue => e` を排除し、具体的な例外クラスのみをrescue
- `render json: { success: false, error: ... }` の手動記述を `render_api_error` に統一
- timeoutレスポンスに `details: { resumable: true/false }` を追加

---

## 5. ファイルアップロードバリデーション（FileUploadValidation）

**ファイル:** `app/controllers/concerns/file_upload_validation.rb`（新規）

### 検証項目

| 項目 | 音声ファイル | 動画ファイル |
|------|------------|------------|
| 最大サイズ | 25MB（Whisper API上限） | 500MB |
| 許可Content-Type | audio/mpeg, audio/mp3, audio/wav, audio/webm 等 | video/mp4, video/webm, video/quicktime 等 |

### 導入箇所

`submit_answer` アクションの冒頭で、パラメータ存在チェック後・DB操作前にバリデーションを実行:

```ruby
validate_audio_upload!(audio_file)
validate_video_upload!(video_file)
```

不正ファイルは `ActionController::BadRequest` → `ApiErrorHandler` で統一的に400レスポンスを返却。

---

## 6. Content-Type検証

**ファイル:** `app/controllers/api/interviews_controller.rb`

POST系エンドポイントに `verify_content_type!` before_actionを追加:

| 許可Content-Type | 対象アクション |
|-----------------|--------------|
| `application/json` | start, start_by_token, complete, resume |
| `multipart/form-data` | submit_answer |

不正なContent-Typeは **415 Unsupported Media Type** で拒否。CSRF保護の代替策として機能。

---

## 7. レガシーAnswerテーブル削除

`interview_responses` テーブルで完全に置き換え済みのレガシーシステムを完全削除。

### 削除対象

| ファイル | 種別 |
|---------|------|
| `app/models/answer.rb` | モデル |
| `app/controllers/answers_controller.rb` | コントローラー |
| `app/views/answers/new.html.slim` | ビュー |
| `config/routes.rb` 内の `resources :answers` | ルーティング |
| `app/models/situation.rb` 内の `has_many :answers` | アソシエーション |
| `app/models/user.rb` 内の `has_many :answers` | アソシエーション |
| `answers` テーブル | DBマイグレーションで削除 |

---

## 8. DBインデックス追加・FK制約追加

**ファイル:** `db/migrate/20260315120000_day9_security_and_db_improvements.rb`

### 追加インデックス

| テーブル | カラム | 用途 |
|---------|--------|------|
| `interviews` | `(status, created_at)` | 管理画面のステータス別一覧表示最適化 |
| `interview_responses` | `created_at` | 時系列での回答一覧最適化 |
| `questions` | `(situation_id, order)` | 面接中の質問順序取得最適化（最頻出クエリ） |
| `situations` | `(client_id, archived)` | クライアント別アクティブシナリオ一覧最適化 |

### 追加FK制約

| From | To | 説明 |
|------|-----|------|
| `situations.client_id` | `clients.id` | 既存スキーマで欠落していた参照整合性制約 |

---

## 9. コントローラー改修まとめ

`app/controllers/api/interviews_controller.rb` の主な変更:

| 項目 | 修正前 | 修正後 |
|------|--------|--------|
| エラーレスポンス | 各アクション個別に `render json:` | `render_api_error` メソッドに統一 |
| 汎用rescue | `rescue => e` が5箇所 | 具体的例外のみrescue（SessionError, AudioError等） |
| ファイル検証 | なし | `validate_audio_upload!` / `validate_video_upload!` |
| Content-Type | チェックなし | `verify_content_type!` before_action |
| 二重回答レスポンス | `status: :bad_request` | `status: :conflict`（409） |
| タイムアウト | resumable情報なし | `details: { resumable: ... }` 追加 |

---

## 10. コードレビュー結果

### Day 1で指摘された課題の対応状況

| # | 課題 | 優先度 | 対応状況 |
|---|------|--------|---------|
| 1 | テストモード認証バイパス | 高 | 既修正済み（`Rails.env.production?` ガード） |
| 2 | CSRF保護なし | 高 | Content-Type検証 + トークン認証で代替 |
| 3 | ファイルアップロード検証なし | 高 | **Day 9で修正** |
| 4 | APIキー起動時検証なし | 高 | **Day 9で修正** |
| 5 | production.rb エラー詳細露出 | 高 | **Day 9で修正** |
| 6 | 本番SQLite | 中 | 未対応（Day 10以降） |
| 7 | 不足インデックス | 中 | **Day 9で修正** |
| 8 | 不足FK制約 | 中 | **Day 9で修正** |
| 9 | APIエラーレスポンス不統一 | 中 | **Day 9で修正** |
| 10 | レガシーAnswerテーブル | 低 | **Day 9で修正** |

### 残存課題

| # | 課題 | 優先度 | 対応予定 |
|---|------|--------|---------|
| 6 | 本番SQLite → PostgreSQL | 中 | Day 10 |
| 11 | RSpecテスト導入 | 中 | Day 11 |
| 12 | ハードコード値のDB/環境変数化 | 低 | Day 12 |
| 11 | ジョブが非同期未使用 | 中 | **Day 10で修正** |
| 12 | Puma 3.x (古い) | 低 | **Day 10で修正** |
| 13 | Gemfile重複 | 低 | **Day 10で修正** |

---

## 11. 変更ファイル一覧（Day 9）

| ファイル | 種別 | 説明 |
|---------|------|------|
| `config/environments/production.rb` | 改修 | エラー詳細非表示、SSL強制、ログレベル変更 |
| `config/initializers/api_key_validation.rb` | **新規** | APIキー起動時検証 |
| `app/controllers/concerns/api_error_handler.rb` | **新規** | 統一エラーレスポンスconcern |
| `app/controllers/concerns/file_upload_validation.rb` | **新規** | ファイルアップロードバリデーションconcern |
| `app/controllers/api/interviews_controller.rb` | 改修 | concern統合、Content-Type検証、エラーレスポンス統一 |
| `app/models/situation.rb` | 改修 | `has_many :answers` 削除 |
| `app/models/user.rb` | 改修 | `has_many :answers` 削除 |
| `config/routes.rb` | 改修 | `resources :answers` 削除 |
| `db/migrate/20260315120000_day9_security_and_db_improvements.rb` | **新規** | インデックス追加、FK制約追加、Answerテーブル削除 |
| `app/models/answer.rb` | **削除** | レガシーモデル |
| `app/controllers/answers_controller.rb` | **削除** | レガシーコントローラー |
| `app/views/answers/new.html.slim` | **削除** | レガシービュー |

---

---

# Day 10 — 本番インフラ整備（PostgreSQL移行・Puma/Sidekiq強化）

## 12. 概要

本番環境のインフラ基盤を整備した。SQLiteからPostgreSQLへの移行準備、Pumaのクラスターモード化、Sidekiqの本番Redis接続設定、デプロイ基盤（Procfile・リリーススクリプト）を構築。

| コンポーネント | 修正前 | 修正後 |
|--------------|--------|--------|
| **データベース** | SQLite3（開発/本番共通） | 開発: SQLite3 / 本番: PostgreSQL |
| **Webサーバー** | Puma 3.x（シングルプロセス） | Puma 5.x（本番: クラスターモード） |
| **ジョブキュー** | :async（メモリ内、再起動で消失） | :sidekiq（Redis永続化） |
| **デプロイ** | 手動 | Procfile + bin/release |

---

## 13. SQLite → PostgreSQL 移行

### Gemfile変更

```ruby
# 修正前
gem 'sqlite3', '~> 1.6'

# 修正後
gem 'pg', '~> 1.5', group: :production
gem 'sqlite3', '~> 1.6', groups: [:development, :test]
```

### database.yml変更

| 環境 | アダプター | 接続先 |
|------|-----------|--------|
| development | sqlite3 | `db/development.sqlite3`（変更なし） |
| test | sqlite3 | `db/test.sqlite3`（変更なし） |
| production | postgresql | `DATABASE_URL` 環境変数（優先）または個別設定 |

---

## 14. Puma 本番設定強化

**ファイル:** `config/puma.rb`

| 設定 | 修正前 | 修正後 |
|------|--------|--------|
| バージョン | Puma 3.x | Puma 5.x |
| ワーカー数 | 未設定 | 本番: `WEB_CONCURRENCY`（デフォルト2） |
| preload_app | 無効 | 本番: 有効（メモリ効率化） |
| DB再接続 | 未設定 | `on_worker_boot` で `establish_connection` |

---

## 15. Sidekiq 本番設定

### sidekiq.yml改善

| 設定 | 修正前 | 修正後 |
|------|--------|--------|
| Redis接続 | ハードコード | `REDIS_URL` 環境変数 |
| キュー構成 | article_generation(5), default(1) | critical(10), default(5), article_generation(3), low(1) |
| 同時実行数 | ハードコード10 | `SIDEKIQ_CONCURRENCY` 環境変数 |

### initializers/sidekiq.rb（新規）

Redis接続をサーバー/クライアント両方で `REDIS_URL` 環境変数から設定。

### Active Job

`config.active_job.queue_adapter` を `:async` から `:sidekiq` に変更。ジョブがRedisに永続化され、サーバー再起動でも消失しない。

---

## 16. デプロイ基盤整備

| ファイル | 説明 |
|---------|------|
| `Procfile` | web + worker プロセス定義（Render/Heroku対応） |
| `bin/release` | デプロイ時の自動マイグレーション実行 |
| `.env.example` | 全環境変数のテンプレート |

---

## 17. Gemfile改善

| 変更 | 修正前 | 修正後 |
|------|--------|--------|
| DB gem | `sqlite3` 全環境 | `pg` 本番 / `sqlite3` 開発・テスト |
| Puma | `~> 3.11` | `~> 5.6` |
| kramdown重複 | 2回定義 | 1回に修正 |

---

## 18. 変更ファイル一覧（Day 10）

| ファイル | 種別 | 説明 |
|---------|------|------|
| `Gemfile` | 改修 | pg追加、sqlite3をdev/test限定、Puma 5.x、kramdown重複修正 |
| `config/database.yml` | 改修 | 本番PostgreSQL対応（DATABASE_URL優先） |
| `config/puma.rb` | 改修 | クラスターモード、preload_app、on_worker_boot |
| `config/sidekiq.yml` | 改修 | キュー優先度整理、ハードコードRedis URL削除 |
| `config/initializers/sidekiq.rb` | **新規** | Redis接続設定 |
| `config/environments/production.rb` | 改修 | queue_adapter: :sidekiq |
| `Procfile` | **新規** | web + worker プロセス定義 |
| `bin/release` | **新規** | デプロイ時自動マイグレーション |
| `.env.example` | **新規** | 環境変数テンプレート |

---

> **フェーズ3 Day 9-10 完了:** セキュリティ強化、DB改善、API品質統一、レガシー削除、本番インフラ整備（PostgreSQL/Puma/Sidekiq/デプロイ基盤）。Day 1で特定された全課題への対応が完了。

---

*AI面接インタビューシステム — Day 9・Day 10 報告書 | 2026-03-15 | master ブランチ*
