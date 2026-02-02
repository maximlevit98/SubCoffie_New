#!/bin/bash

# Performance Tests
# Измерение производительности RPC функций

set -e

echo "========================================="
echo "Performance Tests"
echo "========================================="
echo ""

SUPABASE_URL="http://127.0.0.1:54321"
ANON_KEY="eyJhbGciOiJFUzI1NiIsImtpZCI6ImI4MTI2OWYxLTIxZDgtNGYyZS1iNzE5LWMyMjQwYTg0MGQ5MCIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjIwODUxMjQwNzB9.56-YVSqsoeDSxQF8l97Kdap-0RuohlPdmp36jfrHjT50g-WLMqW3bQAdS0I04IqC7O88dMv561gMQ_LfY-SZkQ"

echo "Test 4.1.1: RPC get_orders_stats response time"
echo "Expected: < 100ms average"
echo ""

# Выполняем 10 запросов и измеряем время
total_time=0
requests=10

for i in $(seq 1 $requests); do
  start=$(date +%s%N)
  
  curl -s -o /dev/null \
    -X POST "$SUPABASE_URL/rest/v1/rpc/get_orders_stats" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json" \
    -d '{}'
  
  end=$(date +%s%N)
  duration=$(( (end - start) / 1000000 )) # convert to ms
  
  total_time=$(( total_time + duration ))
  echo "  Request $i: ${duration}ms"
done

avg_time=$(( total_time / requests ))
echo ""
echo "Average response time: ${avg_time}ms"

if [ $avg_time -lt 100 ]; then
  echo "✅ PASS: Response time < 100ms"
else
  echo "⚠️  WARNING: Response time >= 100ms"
fi

echo ""
echo "========================================="
echo ""

echo "Test 4.1.2: RPC get_dashboard_metrics response time"
echo "Expected: < 150ms average"
echo ""

total_time=0
requests=10

for i in $(seq 1 $requests); do
  start=$(date +%s%N)
  
  curl -s -o /dev/null \
    -X POST "$SUPABASE_URL/rest/v1/rpc/get_dashboard_metrics" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json" \
    -d '{}'
  
  end=$(date +%s%N)
  duration=$(( (end - start) / 1000000 ))
  
  total_time=$(( total_time + duration ))
  echo "  Request $i: ${duration}ms"
done

avg_time=$(( total_time / requests ))
echo ""
echo "Average response time: ${avg_time}ms"

if [ $avg_time -lt 150 ]; then
  echo "✅ PASS: Response time < 150ms"
else
  echo "⚠️  WARNING: Response time >= 150ms"
fi

echo ""
echo "========================================="
echo ""

echo "Test 4.1.3: RPC get_orders_by_cafe response time"
echo "Expected: < 100ms average"
echo ""

total_time=0
requests=10

for i in $(seq 1 $requests); do
  start=$(date +%s%N)
  
  curl -s -o /dev/null \
    -X POST "$SUPABASE_URL/rest/v1/rpc/get_orders_by_cafe" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json" \
    -d '{"cafe_id_param": null, "status_filter": null, "limit_param": 50, "offset_param": 0}'
  
  end=$(date +%s%N)
  duration=$(( (end - start) / 1000000 ))
  
  total_time=$(( total_time + duration ))
  echo "  Request $i: ${duration}ms"
done

avg_time=$(( total_time / requests ))
echo ""
echo "Average response time: ${avg_time}ms"

if [ $avg_time -lt 100 ]; then
  echo "✅ PASS: Response time < 100ms"
else
  echo "⚠️  WARNING: Response time >= 100ms"
fi

echo ""
echo "========================================="
echo "Performance Tests Complete"
echo "========================================="
