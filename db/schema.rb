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

ActiveRecord::Schema.define(version: 2026_03_15_120000) do

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
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["reset_password_token"], name: "index_clients_on_reset_password_token", unique: true
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
    t.json "evaluation_data", default: "\"\\\"\\\\\\\"{}\\\\\\\"\\\"\""
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
    t.json "results_data", default: "\"{}\""
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "rejection_details", default: "\"{}\""
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
    t.index ["client_id", "archived"], name: "index_situations_on_client_id_and_archived"
    t.index ["client_id"], name: "index_situations_on_client_id"
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "interview_responses", "interviews"
  add_foreign_key "interview_responses", "questions"
  add_foreign_key "interview_results", "interviews"
  add_foreign_key "interviews", "situations"
  add_foreign_key "interviews", "users"
  add_foreign_key "question_audios", "questions"
  add_foreign_key "questions", "situations"
  add_foreign_key "situations", "clients"
end
