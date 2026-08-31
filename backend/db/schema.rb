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

ActiveRecord::Schema[8.1].define(version: 2026_08_31_050000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "facebook_page_access_token"
    t.string "facebook_page_id"
    t.string "facebook_page_name"
    t.datetime "facebook_token_expires_at"
    t.string "jueri_webhook_token"
    t.integer "min_pecas_ativa", default: 25, null: false
    t.string "name"
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["facebook_page_id"], name: "index_accounts_on_facebook_page_id"
    t.index ["jueri_webhook_token"], name: "index_accounts_on_jueri_webhook_token", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agendamentos", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id"
    t.datetime "created_at", null: false
    t.text "descricao"
    t.datetime "fim_em"
    t.datetime "inicio_em", null: false
    t.string "tipo", default: "outro", null: false
    t.string "titulo", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "valor", precision: 12, scale: 2
    t.index ["account_id", "inicio_em"], name: "index_agendamentos_on_account_id_and_inicio_em"
    t.index ["account_id"], name: "index_agendamentos_on_account_id"
    t.index ["contact_id"], name: "index_agendamentos_on_contact_id"
    t.index ["user_id", "inicio_em"], name: "index_agendamentos_on_user_id_and_inicio_em"
    t.index ["user_id"], name: "index_agendamentos_on_user_id"
  end

  create_table "contact_audit_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "changed_by_id"
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_value"
    t.string "to_value"
    t.datetime "updated_at", null: false
    t.index ["account_id", "event_type"], name: "index_contact_audit_events_on_account_id_and_event_type"
    t.index ["account_id"], name: "index_contact_audit_events_on_account_id"
    t.index ["changed_by_id"], name: "index_contact_audit_events_on_changed_by_id"
    t.index ["contact_id", "event_type", "created_at"], name: "idx_contact_audit_events_contact_type_time"
    t.index ["contact_id"], name: "index_contact_audit_events_on_contact_id"
  end

  create_table "contact_tags", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.bigint "tag_id", null: false
    t.index ["contact_id", "tag_id"], name: "index_contact_tags_on_contact_and_tag", unique: true
    t.index ["contact_id"], name: "index_contact_tags_on_contact_id"
    t.index ["tag_id"], name: "index_contact_tags_on_tag_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "address_complement"
    t.string "address_number"
    t.string "avatar_url"
    t.text "bio"
    t.date "birth_date"
    t.string "cep"
    t.string "city"
    t.string "company_name"
    t.string "country"
    t.string "cpf"
    t.datetime "created_at", null: false
    t.jsonb "custom_attributes", default: {}
    t.datetime "cycle_started_at"
    t.boolean "desconsiderado", default: false, null: false
    t.datetime "desconsiderado_at"
    t.string "desconsiderado_motivo"
    t.string "email"
    t.string "first_name"
    t.string "id_jueri"
    t.string "instagram_id"
    t.string "intention"
    t.string "jid"
    t.datetime "jueri_synced_at"
    t.string "last_name"
    t.string "name"
    t.string "neighborhood"
    t.string "nivel"
    t.integer "pecas_abertas_atual", default: 0, null: false
    t.integer "pedidos_abertos_count", default: 0, null: false
    t.string "phone"
    t.datetime "snapshot_calculado_em"
    t.string "source"
    t.string "state"
    t.string "status"
    t.datetime "status_changed_at"
    t.string "street"
    t.string "temperature"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id", "created_at"], name: "idx_contacts_account_created_at"
    t.index ["account_id", "desconsiderado"], name: "index_contacts_on_account_id_and_desconsiderado"
    t.index ["account_id", "id_jueri"], name: "index_contacts_on_account_id_and_id_jueri", unique: true
    t.index ["account_id", "instagram_id"], name: "index_contacts_on_account_id_and_instagram_id"
    t.index ["account_id", "jid"], name: "idx_contacts_account_jid_unique", unique: true, where: "(jid IS NOT NULL)"
    t.index ["account_id", "jid"], name: "index_contacts_on_account_id_and_jid"
    t.index ["account_id", "nivel"], name: "index_contacts_on_account_id_and_nivel"
    t.index ["account_id", "source"], name: "idx_contacts_account_source"
    t.index ["account_id", "status"], name: "index_contacts_on_account_id_and_status"
    t.index ["account_id", "temperature"], name: "idx_contacts_account_temperature"
    t.index ["account_id"], name: "index_contacts_on_account_id"
    t.index ["instagram_id"], name: "index_contacts_on_instagram_id"
    t.index ["jid"], name: "index_contacts_on_jid"
    t.index ["pecas_abertas_atual"], name: "index_contacts_on_pecas_abertas_atual"
    t.index ["phone"], name: "index_contacts_on_phone"
    t.index ["status_changed_at"], name: "index_contacts_on_status_changed_at"
    t.index ["user_id"], name: "index_contacts_on_user_id"
  end

  create_table "conversation_tags", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "tag_id", null: false
    t.index ["conversation_id", "tag_id"], name: "index_conversation_tags_on_conversation_and_tag", unique: true
    t.index ["conversation_id"], name: "index_conversation_tags_on_conversation_id"
    t.index ["tag_id"], name: "index_conversation_tags_on_tag_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.integer "followup_count", default: 0
    t.bigint "inbox_id"
    t.datetime "last_activity_at"
    t.datetime "snoozed_until"
    t.string "source"
    t.integer "status", default: 0
    t.integer "unread_count", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id", "status"], name: "index_conversations_on_account_id_and_status"
    t.index ["account_id"], name: "index_conversations_on_account_id"
    t.index ["contact_id"], name: "index_conversations_on_contact_id"
    t.index ["inbox_id", "status"], name: "idx_conversations_inbox_status"
    t.index ["inbox_id"], name: "index_conversations_on_inbox_id"
    t.index ["last_activity_at"], name: "index_conversations_on_last_activity_at"
    t.index ["status"], name: "index_conversations_on_status"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "flow_edges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "flow_id", null: false
    t.string "source_handle"
    t.string "source_key", null: false
    t.string "target_handle"
    t.string "target_key", null: false
    t.datetime "updated_at", null: false
    t.index ["flow_id"], name: "index_flow_edges_on_flow_id"
  end

  create_table "flow_nodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.bigint "flow_id", null: false
    t.string "key", null: false
    t.string "node_type", null: false
    t.jsonb "position", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["flow_id", "key"], name: "index_flow_nodes_on_flow_id_and_key", unique: true
    t.index ["flow_id"], name: "index_flow_nodes_on_flow_id"
  end

  create_table "flow_runs", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "current_node_key"
    t.bigint "flow_id", null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.jsonb "variables", default: {}, null: false
    t.index ["contact_id"], name: "index_flow_runs_on_contact_id"
    t.index ["conversation_id", "status"], name: "index_flow_runs_on_conversation_id_and_status"
    t.index ["conversation_id"], name: "index_flow_runs_on_conversation_id"
    t.index ["flow_id"], name: "index_flow_runs_on_flow_id"
  end

  create_table "flows", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "channel"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "inbox_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "active"], name: "index_flows_on_account_id_and_active"
    t.index ["account_id"], name: "index_flows_on_account_id"
    t.index ["inbox_id"], name: "index_flows_on_inbox_id"
  end

  create_table "global_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_global_settings_on_key", unique: true
  end

  create_table "inbox_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inbox_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["inbox_id", "user_id"], name: "index_inbox_members_on_inbox_id_and_user_id", unique: true
    t.index ["inbox_id"], name: "index_inbox_members_on_inbox_id"
    t.index ["user_id"], name: "index_inbox_members_on_user_id"
  end

  create_table "inboxes", force: :cascade do |t|
    t.bigint "account_id"
    t.boolean "ai_enabled", default: false
    t.string "ai_name"
    t.text "ai_prompt"
    t.float "ai_temperature", default: 0.7
    t.string "api_key"
    t.string "api_url"
    t.text "bot_prompt"
    t.datetime "created_at", null: false
    t.text "followup_closing_message"
    t.boolean "followup_enabled", default: false
    t.integer "followup_max_attempts", default: 3
    t.boolean "followup_send_closing_message", default: false
    t.integer "followup_wait_time_minutes", default: 120
    t.string "instagram_access_token"
    t.string "instagram_business_account_id"
    t.string "instagram_page_id"
    t.datetime "instagram_token_expires_at"
    t.string "instagram_username"
    t.text "knowledge_base"
    t.string "name"
    t.text "out_of_office_message"
    t.string "phone_number"
    t.string "provider"
    t.bigint "round_robin_group_id"
    t.datetime "updated_at", null: false
    t.jsonb "working_hours", default: []
    t.boolean "working_hours_enabled", default: false
    t.index ["account_id"], name: "index_inboxes_on_account_id"
    t.index ["instagram_page_id"], name: "index_inboxes_on_instagram_page_id"
    t.index ["phone_number"], name: "index_inboxes_on_phone_number"
    t.index ["round_robin_group_id"], name: "index_inboxes_on_round_robin_group_id"
  end

  create_table "internal_messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "read_at"
    t.bigint "recipient_id", null: false
    t.bigint "sender_id", null: false
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_internal_messages_on_account_id"
    t.index ["recipient_id", "read_at"], name: "index_internal_messages_on_recipient_id_and_read_at"
    t.index ["recipient_id", "sender_id"], name: "index_internal_messages_on_recipient_id_and_sender_id"
    t.index ["sender_id", "recipient_id"], name: "index_internal_messages_on_sender_id_and_recipient_id"
  end

  create_table "jueri_activities", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id"
    t.datetime "created_at", null: false
    t.string "descricao", null: false
    t.string "evento", null: false
    t.datetime "ocorrido_em", null: false
    t.jsonb "payload", default: {}
    t.datetime "updated_at", null: false
    t.index ["account_id", "ocorrido_em"], name: "index_jueri_activities_on_account_id_and_ocorrido_em"
    t.index ["account_id"], name: "index_jueri_activities_on_account_id"
    t.index ["contact_id"], name: "index_jueri_activities_on_contact_id"
  end

  create_table "lifecycle_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}
    t.datetime "occurred_at", null: false
    t.bigint "pedido_id"
    t.datetime "updated_at", null: false
    t.index ["account_id", "event_type"], name: "index_lifecycle_events_on_account_id_and_event_type"
    t.index ["account_id"], name: "index_lifecycle_events_on_account_id"
    t.index ["contact_id", "event_type", "occurred_at"], name: "idx_lifecycle_events_contact_type_time"
    t.index ["contact_id"], name: "idx_lifecycle_events_iniciada_unica", unique: true, where: "((event_type)::text = 'iniciada'::text)"
    t.index ["contact_id"], name: "index_lifecycle_events_on_contact_id"
    t.index ["pedido_id"], name: "index_lifecycle_events_on_pedido_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_private", default: false
    t.integer "sender_id"
    t.string "sender_type", null: false
    t.string "source_id"
    t.integer "status", default: 0
    t.text "text"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_messages_on_account_id"
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_type", "sender_id"], name: "index_messages_on_sender_type_and_sender_id"
    t.index ["source_id"], name: "index_messages_on_source_id"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_id"], name: "index_notes_on_account_id"
    t.index ["contact_id"], name: "index_notes_on_contact_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "audience"
    t.datetime "created_at", null: false
    t.string "link"
    t.string "message"
    t.datetime "read_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["account_id", "read_at"], name: "idx_notifications_account_read_at"
    t.index ["account_id"], name: "index_notifications_on_account_id"
  end

  create_table "pedidos", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.date "data_acerto"
    t.date "data_baixa"
    t.date "data_cancelamento"
    t.date "data_criacao", null: false
    t.string "jueri_pedido_id", null: false
    t.integer "quantidade", default: 0, null: false
    t.integer "quantidade_antes_baixa"
    t.integer "status_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "valor_total", precision: 12, scale: 2
    t.index ["account_id"], name: "index_pedidos_on_account_id"
    t.index ["contact_id", "data_criacao", "data_baixa", "status_id"], name: "idx_pedidos_ciclo_vida"
    t.index ["contact_id"], name: "idx_pedidos_abertos", where: "(data_baixa IS NULL)"
    t.index ["contact_id"], name: "index_pedidos_on_contact_id"
    t.index ["jueri_pedido_id"], name: "index_pedidos_on_jueri_pedido_id", unique: true
  end

  create_table "pipeline_cards", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.bigint "pipeline_id", null: false
    t.bigint "pipeline_stage_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_pipeline_cards_on_contact_id"
    t.index ["pipeline_id", "contact_id"], name: "index_pipeline_cards_on_pipeline_id_and_contact_id", unique: true
    t.index ["pipeline_id"], name: "index_pipeline_cards_on_pipeline_id"
    t.index ["pipeline_stage_id"], name: "index_pipeline_cards_on_pipeline_stage_id"
  end

  create_table "pipeline_stages", force: :cascade do |t|
    t.string "color", default: "#ff007f"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "pipeline_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_id"], name: "index_pipeline_stages_on_pipeline_id"
  end

  create_table "pipeline_triggers", force: :cascade do |t|
    t.string "action_type", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "pipeline_stage_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_stage_id"], name: "index_pipeline_triggers_on_pipeline_stage_id"
  end

  create_table "pipelines", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "slug"], name: "index_pipelines_on_account_id_and_slug", unique: true
    t.index ["account_id"], name: "index_pipelines_on_account_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.text "auth_key", null: false
    t.datetime "created_at", null: false
    t.text "endpoint", null: false
    t.text "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "regua_triggers", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "action_type", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_regua_triggers_on_account_id_and_status"
    t.index ["account_id"], name: "index_regua_triggers_on_account_id"
  end

  create_table "reseller_phones", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.string "label"
    t.string "phone", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id", "phone"], name: "index_reseller_phones_on_contact_id_and_phone", unique: true
    t.index ["contact_id"], name: "index_reseller_phones_on_contact_id"
    t.index ["phone"], name: "index_reseller_phones_on_phone"
  end

  create_table "round_robin_groups", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_round_robin_groups_on_account_id"
  end

  create_table "sales_team_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "sales_team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["sales_team_id", "user_id"], name: "index_sales_team_memberships_uniq", unique: true
    t.index ["sales_team_id"], name: "index_sales_team_memberships_on_sales_team_id"
    t.index ["user_id"], name: "index_sales_team_memberships_on_user_id"
  end

  create_table "sales_teams", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "jueri_lider_id", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "jueri_lider_id"], name: "index_sales_teams_on_account_and_lider_id", unique: true
    t.index ["account_id"], name: "index_sales_teams_on_account_id"
  end

  create_table "scheduled_messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "send_at"
    t.string "status", default: "pending"
    t.text "text"
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_scheduled_messages_on_conversation_id"
    t.index ["status", "send_at"], name: "idx_scheduled_messages_status_send_at"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "support_ticket_messages", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "support_ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["support_ticket_id"], name: "index_support_ticket_messages_on_support_ticket_id"
    t.index ["user_id"], name: "index_support_ticket_messages_on_user_id"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_support_tickets_on_account_id"
  end

  create_table "tags", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "color", default: "#6b7280"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_tags_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_tags_on_account_id"
  end

  create_table "tarefas", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "concluida_em"
    t.bigint "concluida_por_id"
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.text "descricao"
    t.string "prioridade", default: "normal", null: false
    t.string "status", default: "pendente", null: false
    t.string "tipo", null: false
    t.string "titulo", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.datetime "vencimento_em"
    t.index ["account_id", "status"], name: "index_tarefas_on_account_id_and_status"
    t.index ["account_id"], name: "index_tarefas_on_account_id"
    t.index ["concluida_por_id"], name: "index_tarefas_on_concluida_por_id"
    t.index ["contact_id", "tipo"], name: "idx_tarefas_pendente_unica_por_tipo", unique: true, where: "((status)::text = 'pendente'::text)"
    t.index ["contact_id"], name: "index_tarefas_on_contact_id"
    t.index ["user_id", "status"], name: "index_tarefas_on_user_id_and_status"
    t.index ["user_id"], name: "index_tarefas_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id"
    t.boolean "available_for_roundrobin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "department", default: "corretor", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "jti"
    t.string "jueri_gerente_id"
    t.string "last_name"
    t.jsonb "permissions", default: {}
    t.string "phone"
    t.integer "queue_position"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role"
    t.bigint "round_robin_group_id"
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.index ["account_id", "available_for_roundrobin", "queue_position"], name: "index_users_on_account_roundrobin_queue"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["department"], name: "index_users_on_department"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["round_robin_group_id"], name: "index_users_on_round_robin_group_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agendamentos", "accounts"
  add_foreign_key "agendamentos", "contacts"
  add_foreign_key "agendamentos", "users"
  add_foreign_key "contact_audit_events", "accounts"
  add_foreign_key "contact_audit_events", "contacts"
  add_foreign_key "contact_audit_events", "users", column: "changed_by_id"
  add_foreign_key "contact_tags", "contacts"
  add_foreign_key "contact_tags", "tags"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "contacts", "users"
  add_foreign_key "conversation_tags", "conversations"
  add_foreign_key "conversation_tags", "tags"
  add_foreign_key "conversations", "accounts"
  add_foreign_key "conversations", "contacts"
  add_foreign_key "conversations", "inboxes"
  add_foreign_key "conversations", "users"
  add_foreign_key "flow_edges", "flows"
  add_foreign_key "flow_nodes", "flows"
  add_foreign_key "flow_runs", "contacts"
  add_foreign_key "flow_runs", "conversations"
  add_foreign_key "flow_runs", "flows"
  add_foreign_key "flows", "accounts"
  add_foreign_key "flows", "inboxes"
  add_foreign_key "inbox_members", "inboxes"
  add_foreign_key "inbox_members", "users"
  add_foreign_key "inboxes", "accounts"
  add_foreign_key "inboxes", "round_robin_groups"
  add_foreign_key "internal_messages", "accounts"
  add_foreign_key "internal_messages", "users", column: "recipient_id"
  add_foreign_key "internal_messages", "users", column: "sender_id"
  add_foreign_key "jueri_activities", "accounts"
  add_foreign_key "jueri_activities", "contacts"
  add_foreign_key "lifecycle_events", "accounts"
  add_foreign_key "lifecycle_events", "contacts"
  add_foreign_key "lifecycle_events", "pedidos"
  add_foreign_key "messages", "accounts"
  add_foreign_key "messages", "conversations"
  add_foreign_key "notes", "accounts"
  add_foreign_key "notes", "contacts"
  add_foreign_key "notes", "users"
  add_foreign_key "notifications", "accounts"
  add_foreign_key "pedidos", "accounts"
  add_foreign_key "pedidos", "contacts"
  add_foreign_key "pipeline_cards", "contacts"
  add_foreign_key "pipeline_cards", "pipeline_stages"
  add_foreign_key "pipeline_cards", "pipelines"
  add_foreign_key "pipeline_stages", "pipelines"
  add_foreign_key "pipeline_triggers", "pipeline_stages"
  add_foreign_key "pipelines", "accounts"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "regua_triggers", "accounts"
  add_foreign_key "reseller_phones", "contacts"
  add_foreign_key "round_robin_groups", "accounts"
  add_foreign_key "sales_team_memberships", "sales_teams"
  add_foreign_key "sales_team_memberships", "users"
  add_foreign_key "sales_teams", "accounts"
  add_foreign_key "scheduled_messages", "conversations"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "support_ticket_messages", "support_tickets"
  add_foreign_key "support_ticket_messages", "users"
  add_foreign_key "support_tickets", "accounts"
  add_foreign_key "tags", "accounts"
  add_foreign_key "tarefas", "accounts"
  add_foreign_key "tarefas", "contacts"
  add_foreign_key "tarefas", "users"
  add_foreign_key "tarefas", "users", column: "concluida_por_id"
  add_foreign_key "users", "round_robin_groups"
end
