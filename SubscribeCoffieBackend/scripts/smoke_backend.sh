#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

status_log="$LOG_DIR/supabase_status.log"
reset_log="$LOG_DIR/supabase_db_reset.log"
start_log="$LOG_DIR/supabase_start.log"
error_log="$LOG_DIR/error.log"
status_json="$LOG_DIR/supabase_status.json"

{
  echo "== supabase start =="
  /opt/homebrew/bin/supabase start
} 2>&1 | tee "$start_log" || {
  echo "supabase start failed" | tee -a "$error_log"
  exit 1
}

{
  echo "== supabase status =="
  if /opt/homebrew/bin/supabase status --output json; then
    true
  else
    /opt/homebrew/bin/supabase status
  fi
} 2>&1 | tee "$status_log" || {
  echo "supabase status failed" | tee -a "$error_log"
  exit 1
}

get_anon_key() {
  if /opt/homebrew/bin/supabase status --output json > "$status_json" 2>/dev/null; then
    STATUS_JSON="$status_json" python3 - <<'PY'
import json, os, pathlib
data = json.loads(pathlib.Path(os.environ["STATUS_JSON"]).read_text())
print(data.get("anon_key") or data.get("ANON_KEY", ""))
PY
  else
    /opt/homebrew/bin/supabase status | python3 - <<'PY'
import re, sys
text = sys.stdin.read()
m = re.search(r"(?:anon|ANON)_?\\s*key\\s*:\\s*([A-Za-z0-9_\\-\\.]+)", text, re.IGNORECASE)
print(m.group(1) if m else "")
PY
  fi
}

{
  echo "== supabase db reset =="
  for attempt in 1 2 3; do
    if /opt/homebrew/bin/supabase db reset; then
      break
    fi
    echo "db reset attempt $attempt failed, restarting supabase..." | tee -a "$error_log"
    /opt/homebrew/bin/supabase stop || true
    /opt/homebrew/bin/supabase start
    sleep 3
  done
} 2>&1 | tee "$reset_log" || {
  echo "supabase db reset failed" | tee -a "$error_log"
  exit 1
}

ANON_KEY=""
for attempt in 1 2 3; do
  ANON_KEY="$(get_anon_key || true)"
  if [ -n "$ANON_KEY" ]; then
    break
  fi
  sleep 2
done

if [ -z "$ANON_KEY" ]; then
  echo "anon_key not found after retries" | tee -a "$error_log"
  exit 1
fi

for attempt in 1 2 3; do
  ANON_KEY="$ANON_KEY" "$ROOT_DIR/scripts/curl_smoke.sh" && break
  echo "curl smoke attempt $attempt failed" | tee -a "$error_log"
  sleep 2
done

if [ ! -f "$LOG_DIR/curl_cafes_status.txt" ]; then
  echo "curl smoke failed" | tee -a "$error_log"
  exit 1
fi

echo "== SUMMARY (tail) =="
echo "-- supabase status --"
tail -n 40 "$status_log"
echo "-- supabase start --"
tail -n 20 "$start_log"
echo "-- supabase db reset --"
tail -n 40 "$reset_log"
echo "-- curl cafes --"
echo "status: $(cat "$LOG_DIR/curl_cafes_status.txt")"
tail -n 10 "$LOG_DIR/curl_cafes_body.json"
echo "-- curl cafes filters --"
echo "status: $(cat "$LOG_DIR/curl_cafes_filters_status.txt")"
tail -n 10 "$LOG_DIR/curl_cafes_filters_body.json"
echo "-- curl menu_items --"
echo "status: $(cat "$LOG_DIR/curl_menu_items_status.txt")"
tail -n 10 "$LOG_DIR/curl_menu_items_body.json"
echo "-- curl menu_items prep --"
echo "status: $(cat "$LOG_DIR/curl_menu_items_prep_status.txt")"
tail -n 10 "$LOG_DIR/curl_menu_items_prep_body.json"
echo "-- curl orders --"
echo "status: $(cat "$LOG_DIR/curl_orders_status.txt")"
tail -n 10 "$LOG_DIR/curl_orders_body.json"
echo "-- curl rpc get_time_slots --"
echo "status: $(cat "$LOG_DIR/curl_rpc_time_slots_status.txt")"
tail -n 10 "$LOG_DIR/curl_rpc_time_slots_body.json"
echo "-- curl rest root --"
echo "status: $(cat "$LOG_DIR/curl_rest_root_status.txt")"
tail -n 10 "$LOG_DIR/curl_rest_root_body.json"
