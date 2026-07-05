# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_07_05_120100) do

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "clients", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "stripe_customer_id"
    t.string "api_key"
    t.string "subscription_plan"
    t.string "subscription_status"
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["reset_password_token"], name: "index_clients_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_clients_on_stripe_customer_id", unique: true
  end

  create_table "columns", force: :cascade do |t|
    t.string "title"
    t.string "file"
    t.string "choice"
    t.string "keyword"
    t.string "description"
    t.string "status", default: "draft"
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "genre"
    t.string "code"
    t.string "article_type", default: "cluster", null: false
    t.integer "parent_id"
    t.integer "cluster_limit"
    t.text "prompt"
    t.index ["article_type"], name: "index_columns_on_article_type"
    t.index ["code"], name: "index_columns_on_code", unique: true
    t.index ["parent_id"], name: "index_columns_on_parent_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.string "company"
    t.string "name"
    t.string "tel"
    t.string "email"
    t.string "address"
    t.string "url"
    t.string "service"
    t.string "period"
    t.string "message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "deal_audios", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.bigint "file_size"
    t.integer "duration_seconds"
    t.integer "segment_count", default: 0
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id"], name: "index_deal_audios_on_deal_id"
  end

  create_table "deal_documents", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.bigint "file_size"
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "document_kind", default: "proposal", null: false
    t.index ["deal_id", "document_kind"], name: "index_deal_documents_on_deal_id_and_document_kind"
    t.index ["deal_id"], name: "index_deal_documents_on_deal_id"
  end

  create_table "deal_evaluations", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.integer "user_id", null: false
    t.integer "rating", null: false
    t.text "feedback"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id", "user_id"], name: "index_deal_evaluations_on_deal_id_and_user_id", unique: true
    t.index ["deal_id"], name: "index_deal_evaluations_on_deal_id"
    t.index ["user_id"], name: "index_deal_evaluations_on_user_id"
  end

  create_table "deal_faqs", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.text "question", null: false
    t.text "answer"
    t.string "category", default: "other", null: false
    t.string "source", default: "manual", null: false
    t.string "status", default: "approved", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id", "position"], name: "index_deal_faqs_on_deal_id_and_position"
    t.index ["deal_id", "status"], name: "index_deal_faqs_on_deal_id_and_status"
    t.index ["deal_id"], name: "index_deal_faqs_on_deal_id"
  end

  create_table "deal_pages", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.integer "deal_document_id", null: false
    t.integer "page_number", null: false
    t.text "script"
    t.string "audio_url"
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "title"
    t.text "page_text"
    t.index ["deal_document_id"], name: "index_deal_pages_on_deal_document_id"
    t.index ["deal_id", "page_number"], name: "index_deal_pages_on_deal_id_and_page_number", unique: true
    t.index ["deal_id"], name: "index_deal_pages_on_deal_id"
  end

  create_table "deal_presentation_events", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.integer "user_id"
    t.integer "user_progress_id"
    t.string "session_key", null: false
    t.string "event_type", null: false
    t.integer "page_number"
    t.string "topic"
    t.string "label"
    t.text "message"
    t.json "metadata", default: {}
    t.datetime "occurred_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id", "occurred_at"], name: "idx_deal_pres_events_on_deal_and_time"
    t.index ["deal_id", "user_id", "occurred_at"], name: "idx_deal_pres_events_on_deal_user_time"
    t.index ["deal_id"], name: "index_deal_presentation_events_on_deal_id"
    t.index ["event_type"], name: "idx_deal_pres_events_on_event_type"
    t.index ["session_key", "occurred_at"], name: "idx_deal_pres_events_on_session_time"
    t.index ["user_id"], name: "index_deal_presentation_events_on_user_id"
    t.index ["user_progress_id"], name: "index_deal_presentation_events_on_user_progress_id"
  end

  create_table "deal_presentations", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.integer "situation_id", null: false
    t.integer "status", default: 0
    t.text "current_step"
    t.json "user_choices", default: []
    t.json "guidance_history", default: []
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id"], name: "index_deal_presentations_on_deal_id"
    t.index ["situation_id"], name: "index_deal_presentations_on_situation_id"
  end

  create_table "deal_segments", force: :cascade do |t|
    t.integer "deal_audio_id", null: false
    t.integer "segment_number", null: false
    t.float "start_time"
    t.float "end_time"
    t.integer "duration_seconds"
    t.string "audio_file_path"
    t.integer "transcription_status", default: 0
    t.text "transcript"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_audio_id", "segment_number"], name: "index_deal_segments_on_audio_and_number", unique: true
    t.index ["deal_audio_id"], name: "index_deal_segments_on_deal_audio_id"
    t.index ["transcription_status"], name: "index_deal_segments_on_transcription_status"
  end

  create_table "deal_speeches", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.string "filename"
    t.string "content_type"
    t.bigint "file_size"
    t.string "voice"
    t.string "language"
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id"], name: "index_deal_speeches_on_deal_id"
  end

  create_table "deal_summaries", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.text "summary", null: false
    t.text "key_points"
    t.text "action_items"
    t.text "participants"
    t.text "next_steps"
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id"], name: "index_deal_summaries_on_deal_id"
  end

  create_table "deal_transcripts", force: :cascade do |t|
    t.integer "deal_id", null: false
    t.text "full_transcript", null: false
    t.integer "segment_count"
    t.float "total_duration_seconds"
    t.json "metadata", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id"], name: "index_deal_transcripts_on_deal_id"
  end

  create_table "deals", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "status", default: 0
    t.datetime "deal_date"
    t.string "language", default: "ja"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "access_token"
    t.text "greeting_script"
    t.text "company_overview_script"
    t.text "usage_guide_script"
    t.json "menu_items", default: []
    t.boolean "playback_ready", default: false, null: false
    t.string "presentation_cta_label", default: "契約を進める", null: false
    t.string "presentation_cta_url"
    t.string "exit_contract_label", default: "契約へ進む", null: false
    t.string "exit_sales_call_label", default: "担当者と商談を希望", null: false
    t.string "industry", default: "general", null: false
    t.index ["access_token"], name: "index_deals_on_access_token", unique: true
    t.index ["client_id", "status"], name: "index_deals_on_client_id_and_status"
    t.index ["client_id"], name: "index_deals_on_client_id"
    t.index ["industry"], name: "index_deals_on_industry"
    t.index ["status"], name: "index_deals_on_status"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "interview_responses", force: :cascade do |t|
    t.integer "interview_id", null: false
    t.integer "question_id", null: false
    t.text "audio_transcript", null: false
    t.integer "evaluation_status", default: 0
    t.json "evaluation_data", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_interview_responses_on_created_at"
    t.index ["evaluation_status"], name: "index_interview_responses_on_evaluation_status"
    t.index ["interview_id", "question_id"], name: "index_responses_on_interview_and_question", unique: true
    t.index ["interview_id"], name: "index_interview_responses_on_interview_id"
    t.index ["question_id"], name: "index_interview_responses_on_question_id"
  end

  create_table "interview_results", force: :cascade do |t|
    t.integer "interview_id", null: false
    t.integer "final_status"
    t.json "results_data", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "rejection_details", default: {}
    t.index ["final_status"], name: "index_interview_results_on_final_status"
    t.index ["interview_id"], name: "index_interview_results_on_interview_id"
    t.index ["interview_id"], name: "index_interview_results_on_interview_id_unique", unique: true
  end

  create_table "interviews", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "situation_id", null: false
    t.integer "status", default: 0
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "language", default: "en", null: false
    t.string "access_token"
    t.datetime "last_activity_at"
    t.datetime "resumed_at"
    t.integer "resume_count", default: 0, null: false
    t.string "rejection_reason"
    t.datetime "rejected_at"
    t.index ["access_token"], name: "index_interviews_on_access_token", unique: true
    t.index ["situation_id"], name: "index_interviews_on_situation_id"
    t.index ["status", "created_at"], name: "index_interviews_on_status_and_created_at"
    t.index ["user_id", "situation_id"], name: "index_interviews_on_user_and_situation", unique: true
    t.index ["user_id"], name: "index_interviews_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "client_id", null: false
    t.integer "campaign_id"
    t.integer "amount", default: 0, null: false
    t.string "status"
    t.string "stripe_payment_intent_id"
    t.string "description"
    t.index ["campaign_id"], name: "index_payments_on_campaign_id"
    t.index ["client_id"], name: "index_payments_on_client_id"
    t.index ["stripe_payment_intent_id"], name: "index_payments_on_stripe_payment_intent_id", unique: true
  end

  create_table "question_audios", force: :cascade do |t|
    t.integer "question_id", null: false
    t.string "language", default: "en", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["question_id", "language"], name: "index_question_audios_on_question_id_and_language", unique: true
    t.index ["question_id"], name: "index_question_audios_on_question_id"
  end

  create_table "questions", force: :cascade do |t|
    t.integer "situation_id", null: false
    t.text "question_text", null: false
    t.string "question_type", null: false
    t.json "options"
    t.integer "order"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "required", default: true, null: false
    t.string "category"
    t.json "branching_rules"
    t.index ["situation_id", "order"], name: "index_questions_on_situation_id_and_order"
    t.index ["situation_id"], name: "index_questions_on_situation_id"
  end

  create_table "situations", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "client_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "language", default: "en", null: false
    t.boolean "archived", default: false, null: false
    t.integer "session_timeout_minutes", default: 60, null: false
    t.boolean "allow_resume", default: true, null: false
    t.integer "max_resume_count", default: 3, null: false
    t.integer "passing_score", default: 70, null: false
    t.boolean "auto_reject_enabled", default: true, null: false
    t.boolean "reject_on_required_fail", default: true, null: false
    t.integer "min_required_score", default: 70, null: false
    t.integer "max_consecutive_fails", default: 0, null: false
    t.string "reject_notify_method", default: "in_app", null: false
    t.integer "deal_id"
    t.string "situation_type"
    t.index ["client_id", "archived"], name: "index_situations_on_client_id_and_archived"
    t.index ["client_id"], name: "index_situations_on_client_id"
    t.index ["deal_id"], name: "index_situations_on_deal_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "plan_type", null: false
    t.string "status", default: "active", null: false
    t.datetime "trial_ends_at"
    t.string "stripe_subscription_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["client_id"], name: "index_subscriptions_on_client_id"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
  end

  create_table "user_progresses", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "deal_id", null: false
    t.string "consideration_phase"
    t.date "planned_introduction_date"
    t.text "key_points_for_application"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deal_id"], name: "index_user_progresses_on_deal_id"
    t.index ["user_id", "deal_id"], name: "index_user_progresses_on_user_id_and_deal_id", unique: true
    t.index ["user_id"], name: "index_user_progresses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name"
    t.string "company"
    t.string "tel"
    t.text "address"
    t.string "url"
    t.index ["company"], name: "index_users_on_company"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "deal_audios", "deals"
  add_foreign_key "deal_documents", "deals"
  add_foreign_key "deal_evaluations", "deals"
  add_foreign_key "deal_evaluations", "users"
  add_foreign_key "deal_faqs", "deals"
  add_foreign_key "deal_pages", "deal_documents"
  add_foreign_key "deal_pages", "deals"
  add_foreign_key "deal_presentation_events", "deals"
  add_foreign_key "deal_presentation_events", "user_progresses"
  add_foreign_key "deal_presentation_events", "users"
  add_foreign_key "deal_presentations", "deals"
  add_foreign_key "deal_presentations", "situations"
  add_foreign_key "deal_segments", "deal_audios"
  add_foreign_key "deal_speeches", "deals"
  add_foreign_key "deal_summaries", "deals"
  add_foreign_key "deal_transcripts", "deals"
  add_foreign_key "deals", "clients"
  add_foreign_key "interview_responses", "interviews"
  add_foreign_key "interview_responses", "questions"
  add_foreign_key "interview_results", "interviews"
  add_foreign_key "interviews", "situations"
  add_foreign_key "interviews", "users"
  add_foreign_key "payments", "clients"
  add_foreign_key "question_audios", "questions"
  add_foreign_key "questions", "situations"
  add_foreign_key "situations", "clients"
  add_foreign_key "situations", "deals"
  add_foreign_key "subscriptions", "clients"
  add_foreign_key "user_progresses", "deals"
  add_foreign_key "user_progresses", "users"
end
