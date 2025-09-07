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

ActiveRecord::Schema[8.0].define(version: 2025_09_07_152148) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
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
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "burn_events", force: :cascade do |t|
    t.string "theme"
    t.integer "year"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "photo_sessions", force: :cascade do |t|
    t.integer "session_day_id", null: false
    t.integer "session_number"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "burst_id"
    t.string "source"
    t.integer "photo_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "hidden", default: false, null: false
    t.index ["session_day_id"], name: "index_photo_sessions_on_session_day_id"
  end

  create_table "photos", force: :cascade do |t|
    t.integer "photo_session_id", null: false
    t.integer "sitting_id"
    t.string "filename"
    t.string "original_path"
    t.integer "position"
    t.boolean "rejected", default: false
    t.text "metadata"
    t.text "exif_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "face_data"
    t.datetime "face_detected_at"
    t.index ["face_data"], name: "index_photos_on_face_data"
    t.index ["photo_session_id"], name: "index_photos_on_photo_session_id"
    t.index ["sitting_id"], name: "index_photos_on_sitting_id"
  end

  create_table "session_days", force: :cascade do |t|
    t.integer "burn_event_id", null: false
    t.string "day_name"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["burn_event_id"], name: "index_session_days_on_burn_event_id"
  end

  create_table "sittings", force: :cascade do |t|
    t.integer "photo_session_id", null: false
    t.string "name"
    t.string "email"
    t.integer "position"
    t.integer "hero_photo_id"
    t.integer "shock_intensity"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_session_id"], name: "index_sittings_on_photo_session_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "photo_sessions", "session_days"
  add_foreign_key "photos", "photo_sessions"
  add_foreign_key "photos", "sittings"
  add_foreign_key "session_days", "burn_events"
  add_foreign_key "sittings", "photo_sessions"
end
