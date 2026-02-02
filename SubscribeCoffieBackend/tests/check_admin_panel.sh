#!/bin/bash

# Quick Admin Panel Availability Check
# Проверяет доступность основных страниц админ-панели

echo "========================================="
echo "Admin Panel Availability Check"
echo "========================================="
echo ""

ADMIN_URL="http://localhost:3000"
PAGES=(
  "/admin/dashboard"
  "/admin/orders"
  "/admin/wallets"
  "/admin/cafes"
  "/admin/menu-items"
)

check_page() {
  local url=$1
  local response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  
  if [ "$response" == "200" ] || [ "$response" == "307" ] || [ "$response" == "302" ]; then
    echo "✅ $url - OK (HTTP $response)"
    return 0
  else
    echo "❌ $url - FAIL (HTTP $response)"
    return 1
  fi
}

echo "Checking admin panel at $ADMIN_URL..."
echo ""

passed=0
failed=0

for page in "${PAGES[@]}"; do
  if check_page "$ADMIN_URL$page"; then
    ((passed++))
  else
    ((failed++))
  fi
done

echo ""
echo "========================================="
echo "Results: $passed passed, $failed failed"
echo "========================================="

if [ $failed -eq 0 ]; then
  echo "✅ All pages accessible!"
  exit 0
else
  echo "❌ Some pages are not accessible"
  echo "Make sure admin panel is running: cd subscribecoffie-admin && npm run dev"
  exit 1
fi
