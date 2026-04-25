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

ActiveRecord::Schema[7.2].define(version: 2026_04_24_095720) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "pages", primary_key: "title", id: :text, force: :cascade do |t|
    t.text "url", null: false
    t.text "language", default: "en", null: false
    t.datetime "last_updated", precision: nil
    t.text "content", null: false
  end

  create_table "search_logs", force: :cascade do |t|
    t.string "query"
    t.string "path"
    t.string "http_method"
    t.integer "status"
    t.string "ip"
    t.float "duration_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_search_logs_on_created_at"
  end

  create_table "users", force: :cascade do |t|
    t.text "username", null: false
    t.text "email", null: false
    t.text "password"
    t.text "password_digest"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end
end
