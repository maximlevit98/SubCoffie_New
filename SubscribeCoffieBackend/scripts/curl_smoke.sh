#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

status_json="$LOG_DIR/supabase_status.json"
status_txt="$LOG_DIR/supabase_status.txt"
error_log="$LOG_DIR/error.log"

if [ -z "${ANON_KEY:-}" ]; then
  if /opt/homebrew/bin/supabase status --output json > "$status_json" 2>/dev/null; then
    ANON_KEY="$(STATUS_JSON="$status_json" python3 - <<'PY'
import json, os, pathlib
data = json.loads(pathlib.Path(os.environ["STATUS_JSON"]).read_text())
print(data.get("anon_key") or data.get("ANON_KEY", ""))
PY
    )"
  else
    /opt/homebrew/bin/supabase status > "$status_txt"
    ANON_KEY="$(STATUS_TXT="$status_txt" python3 - <<'PY'
import os, pathlib, re
text = pathlib.Path(os.environ["STATUS_TXT"]).read_text()
m = re.search(r"(?:anon|ANON)_?\\s*key\\s*:\\s*([A-Za-z0-9_\\-\\.]+)", text, re.IGNORECASE)
print(m.group(1) if m else "")
PY
    )"
  fi
fi

if [ -z "$ANON_KEY" ]; then
  echo "anon_key not found in supabase status output" | tee -a "$error_log"
  exit 1
fi

BASE_URL="http://127.0.0.1:54321"

run_curl() {
  local name="$1"
  local method="$2"
  local url="$3"
  local data="${4:-}"
  local out_body="$LOG_DIR/${name}_body.json"
  local out_headers="$LOG_DIR/${name}_headers.txt"
  local out_status="$LOG_DIR/${name}_status.txt"

  if [ "$method" = "POST" ]; then
    status_code=$(curl -sS -o "$out_body" -D "$out_headers" -w "%{http_code}" \
      -H "apikey: $ANON_KEY" \
      -H "Authorization: Bearer $ANON_KEY" \
      -H "Content-Type: application/json" \
      -X POST "$url" -d "$data")
  else
    status_code=$(curl -sS -o "$out_body" -D "$out_headers" -w "%{http_code}" \
      -H "apikey: $ANON_KEY" \
      -H "Authorization: Bearer $ANON_KEY" \
      "$url")
  fi

  echo "$status_code" > "$out_status"
  if [ "$status_code" != "200" ]; then
    echo "$name returned HTTP $status_code" | tee -a "$error_log"
    return 1
  fi
}

run_curl "curl_cafes" "GET" "$BASE_URL/rest/v1/cafes?select=id,name&limit=1"
run_curl "curl_cafes_filters" "GET" "$BASE_URL/rest/v1/cafes?select=id,name,rating,avg_check_credits&limit=1"
run_curl "curl_menu_items" "GET" "$BASE_URL/rest/v1/menu_items?select=id,cafe_id,category,name,price_credits&limit=1"
run_curl "curl_menu_items_prep" "GET" "$BASE_URL/rest/v1/menu_items?select=id,name,prep_time_sec&limit=1"
run_curl "curl_orders" "GET" "$BASE_URL/rest/v1/orders?select=id,status&limit=1"
run_curl "curl_rpc_time_slots" "POST" "$BASE_URL/rest/v1/rpc/get_time_slots" \
  '{"p_cafe_id":"11111111-1111-1111-1111-111111111111","p_cart_items":[{"id":"x","qty":1,"prep_time_sec":120}],"p_now":"2026-01-23T10:00:00Z"}'
run_curl "curl_rest_root" "GET" "$BASE_URL/rest/v1/"

# Per-cafe menu smoke (ensure each cafe has items)
CAFE_IDS=(
  "11111111-1111-1111-1111-111111111111"
  "22222222-2222-2222-2222-222222222222"
  "33333333-3333-3333-3333-333333333333"
  "44444444-4444-4444-4444-444444444444"
  "55555555-5555-5555-5555-555555555555"
)

for cafe_id in "${CAFE_IDS[@]}"; do
  run_curl "curl_menu_items_${cafe_id}" "GET" \
    "$BASE_URL/rest/v1/menu_items?select=id,cafe_id,category,price_credits&cafe_id=eq.${cafe_id}&limit=1"

  if [ "$(tr -d '[:space:]' < "$LOG_DIR/curl_menu_items_${cafe_id}_body.json")" = "[]" ]; then
    echo "menu_items returned empty array for cafe_id=${cafe_id}" | tee -a "$error_log"
    exit 1
  fi
done

if [ "$(tr -d '[:space:]' < "$LOG_DIR/curl_cafes_body.json")" = "[]" ]; then
  echo "cafes returned empty array" | tee -a "$error_log"
  exit 1
fi
if [ "$(tr -d '[:space:]' < "$LOG_DIR/curl_menu_items_body.json")" = "[]" ]; then
  echo "menu_items returned empty array" | tee -a "$error_log"
  exit 1
fi
