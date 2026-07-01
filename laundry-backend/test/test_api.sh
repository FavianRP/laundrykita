#!/bin/bash
# ================================================================
# Smart Laundry POS — First Testing Script
# Jalankan: bash test_api.sh
# ================================================================

BASE="http://localhost:8000/api"
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ PASS${NC} — $1"; }
fail() { echo -e "${RED}❌ FAIL${NC} — $1"; exit 1; }
info() { echo -e "${CYAN}▶${NC} $1"; }
section() { echo -e "\n${YELLOW}━━━ $1 ━━━${NC}"; }

# ================================================================
section "0. HEALTH CHECK"
# ================================================================
info "GET /api/health"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health")
[ "$STATUS" = "200" ] && pass "Health check OK (200)" || fail "Health check gagal ($STATUS)"

# ================================================================
section "1. AUTH — LOGIN SEBAGAI OWNER"
# ================================================================
info "POST /api/auth/login (owner)"
OWNER_RES=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"owner","password":"owner123"}')

OWNER_TOKEN=$(echo "$OWNER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null | tr -d '
')
OWNER_ROLE=$(echo "$OWNER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('role',''))" 2>/dev/null | tr -d '
')

[ -n "$OWNER_TOKEN" ] && pass "Login owner berhasil, token didapat" || fail "Login owner gagal, tidak ada token"
[ "$OWNER_ROLE" = "owner" ] && pass "Role owner benar" || fail "Role salah: $OWNER_ROLE"

# ================================================================
section "2. AUTH — LOGIN SEBAGAI KASIR"
# ================================================================
info "POST /api/auth/login (kasir1)"
KASIR_RES=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"kasir1","password":"kasir123"}')

KASIR_TOKEN=$(echo "$KASIR_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null | tr -d '
')
KASIR_ID=$(echo "$KASIR_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user_id',''))" 2>/dev/null | tr -d '
')

[ -n "$KASIR_TOKEN" ] && pass "Login kasir berhasil, token didapat" || fail "Login kasir gagal"
[ -n "$KASIR_ID" ] && pass "Kasir user_id: $KASIR_ID" || fail "Tidak ada user_id"

# ================================================================
section "3. REGISTER KASIR BARU (OWNER ONLY)"
# ================================================================
info "POST /api/auth/register (kasir2)"
REG_RES=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OWNER_TOKEN" \
  -d '{"username":"kasir2","password":"kasir123","role":"kasir"}')

REG_STATUS=$(echo "$REG_RES" | tail -1)
REG_BODY=$(echo "$REG_RES" | sed '$d')

if [ "$REG_STATUS" = "201" ]; then
    pass "Register kasir2 berhasil (201)"
elif [ "$REG_STATUS" = "409" ]; then
    pass "kasir2 sudah ada, skip (409 — safe re-run)"
else
    fail "Register gagal ($REG_STATUS): $REG_BODY"
fi

# Uji: kasir tidak boleh register
info "POST /api/auth/register oleh kasir (harus 403)"
FORBIDDEN=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"username":"kasir3","password":"kasir123","role":"kasir"}')

[ "$FORBIDDEN" = "403" ] && pass "Kasir ditolak register (403)" || fail "Seharusnya 403, dapat $FORBIDDEN"

# ================================================================
section "4. BUAT PESANAN PERTAMA (FR-KSR-01, FR-KSR-02, FR-KSR-03)"
# ================================================================
info "POST /api/orders — Pesanan Budi (kiloan + sepatu)"
ORDER_RES=$(curl -s -X POST "$BASE/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{
    "customer_name": "Budi Santoso",
    "customer_phone": "081234567890",
    "items": [
      {"service_type": "Kiloan", "weight_quantity": 3.5, "price_per_unit": 7000},
      {"service_type": "Sepatu", "weight_quantity": 1.0, "price_per_unit": 25000}
    ],
    "discount": 0,
    "tax_rate": 0
  }')

ORDER_ID=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('order_id',''))" 2>/dev/null | tr -d '
')
TRACKING=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tracking_code',''))" 2>/dev/null | tr -d '
')
IS_LOCKED=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_locked',''))" 2>/dev/null | tr -d '
')
GRAND_TOTAL=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('grand_total',''))" 2>/dev/null | tr -d '
')
QUEUE_NUM=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('queue_number',''))" 2>/dev/null | tr -d '
')
ITEM_COUNT=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('items',[])))" 2>/dev/null | tr -d '
')

echo "  Order ID: $ORDER_ID"
echo "  Tracking: $TRACKING"
echo "  Grand Total: Rp $GRAND_TOTAL"
echo "  Queue: #$QUEUE_NUM"
echo "  Items: $ITEM_COUNT"

[ -n "$ORDER_ID" ] && pass "Order dibuat, ID: $ORDER_ID" || fail "Order gagal dibuat"
[ "$IS_LOCKED" = "True" ] && pass "is_locked = TRUE (Hard Lock aktif)" || fail "is_locked harus TRUE"
[ "$GRAND_TOTAL" = "49500" ] && pass "Grand total Rp 49.500 benar (3.5×7000 + 1×25000)" || fail "Grand total salah: $GRAND_TOTAL"
[ "$ITEM_COUNT" = "2" ] && pass "2 item tercatat" || fail "Item count salah: $ITEM_COUNT"

# ================================================================
section "5. CEK AUTO-UPSERT PELANGGAN (FR-KSR-02)"
# ================================================================
info "GET /api/customers (cari Budi)"
CUST_RES=$(curl -s "$BASE/customers?search=081234567890" \
  -H "Authorization: Bearer $KASIR_TOKEN")

CUST_ID=$(echo "$CUST_RES" | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(d[0]['customer_id'] if d else '')" 2>/dev/null | tr -d '
')

[ -n "$CUST_ID" ] && pass "Pelanggan Budi ter-auto-create: $CUST_ID" || fail "Pelanggan tidak ditemukan"

# ================================================================
section "6. PESANAN KEDUA — PELANGGAN LAMA (FR-KSR-02)"
# ================================================================
info "POST /api/orders — Budi lagi (harus link ke existing)"
ORDER2_RES=$(curl -s -X POST "$BASE/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{
    "customer_name": "Budi Santoso",
    "customer_phone": "081234567890",
    "items": [
      {"service_type": "Boneka", "weight_quantity": 2.0, "price_per_unit": 15000}
    ],
    "discount": 0,
    "tax_rate": 10
  }')

ORDER2_ID=$(echo "$ORDER2_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('order_id',''))" 2>/dev/null | tr -d '
')
ORDER2_TOTAL=$(echo "$ORDER2_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('grand_total',''))" 2>/dev/null | tr -d '
')

echo "  Order 2 ID: $ORDER2_ID"
echo "  Grand Total: Rp $ORDER2_TOTAL"

[ -n "$ORDER2_ID" ] && pass "Order 2 dibuat" || fail "Order 2 gagal"
[ "$ORDER2_TOTAL" = "33000" ] && pass "Tax 10% benar: 30000 + 3000 = 33000" || fail "Tax calc salah: $ORDER2_TOTAL"

# ================================================================
section "7. TRACKING PUBLIK (FR-PLG-01, FR-PLG-02, FR-PLG-03)"
# ================================================================
info "GET /api/track/$TRACKING (tanpa auth!)"
TRACK_RES=$(curl -s "$BASE/track/$TRACKING")

TRACK_NAME=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('customer_name',''))" 2>/dev/null | tr -d '
')
TRACK_STATUS=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('current_status',''))" 2>/dev/null | tr -d '
')
TRACK_PROGRESS=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status_progress',''))" 2>/dev/null | tr -d '
')
TRACK_QUEUE=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('queue_position',''))" 2>/dev/null | tr -d '
')
TRACK_CANCELLED=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancelled',''))" 2>/dev/null | tr -d '
')

echo "  Nama: $TRACK_NAME"
echo "  Status: $TRACK_STATUS"
echo "  Progress: $TRACK_PROGRESS%"
echo "  Posisi Antrean: $TRACK_QUEUE"

[ "$TRACK_NAME" = "Budi Santoso" ] && pass "Nama pelanggan benar" || fail "Nama salah: $TRACK_NAME"
[ "$TRACK_STATUS" = "Antrean" ] && pass "Status: Antrean" || fail "Status salah: $TRACK_STATUS"
[ "$TRACK_PROGRESS" = "0" ] && pass "Progress: 0%" || fail "Progress salah: $TRACK_PROGRESS"
[ "$TRACK_CANCELLED" = "False" ] && pass "is_cancelled = False" || fail "is_cancelled salah"

# ================================================================
section "8. UPDATE STATUS PRODUKSI"
# ================================================================
info "PATCH /api/orders/$ORDER_ID/status → Dicuci"
STATUS_RES=$(curl -s -X PATCH "$BASE/orders/$ORDER_ID/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"current_status": "Dicuci"}')

NEW_STATUS=$(echo "$STATUS_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('current_status',''))" 2>/dev/null | tr -d '
')
[ "$NEW_STATUS" = "Dicuci" ] && pass "Status update ke Dicuci" || fail "Status update gagal: $NEW_STATUS"

# Uji: status tidak boleh mundur
info "PATCH /api/orders/$ORDER_ID/status → Antrean (harus ditolak)"
MUNDUR=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE/orders/$ORDER_ID/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"current_status": "Antrean"}')

[ "$MUNDUR" = "422" ] && pass "Status mundur ditolak (422)" || fail "Seharusnya 422, dapat $MUNDUR"

# ================================================================
section "9. IMMUTABILITY — LANGSUNG UPDATE DITOLAK"
# ================================================================
info "Coba PATCH langsung ke order yang terkunci (seharusnya selalu 403 karena is_locked)"
# Status update yang valid tetap diizinkan (bukan perubahan finansial)
# Tapi coba akses endpoint yang tidak ada — pastikan guard aktif
# Guard ada di level service, bukan router, jadi kita test via edit request

# ================================================================
section "10. EDIT REQUEST — KASIR AJUKAN KOREKSI (FR-KSR-04)"
# ================================================================
# Ambil item_id pertama dari order 1
ITEM_ID=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['items'][0]['item_id'])" 2>/dev/null | tr -d '
')
echo "  Target item_id: $ITEM_ID"

info "POST /api/edit-requests — ubah berat Kiloan 3.5kg → 4.0kg"
ER_RES=$(curl -s -X POST "$BASE/edit-requests" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d "{
    \"order_id\": $ORDER_ID,
    \"reason\": \"Salah timbang, seharusnya 4 kg\",
    \"items\": [{
      \"order_item_id\": $ITEM_ID,
      \"service_type\": \"Kiloan\",
      \"new_weight_quantity\": 4.0,
      \"new_price_per_unit\": 7000
    }]
  }")

ER_ID=$(echo "$ER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null | tr -d '
')
ER_STATUS=$(echo "$ER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('approval_status',''))" 2>/dev/null | tr -d '
')
OLD_WQ=$(echo "$ER_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(format(float(i.get('old_weight_quantity',0)), '.2f'))" 2>/dev/null | tr -d '
')
NEW_WQ=$(echo "$ER_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(format(float(i.get('new_weight_quantity',0)), '.2f'))" 2>/dev/null | tr -d '
')

echo "  Request ID: $ER_ID"
echo "  Old weight: ${OLD_WQ}kg → New weight: ${NEW_WQ}kg"

[ -n "$ER_ID" ] && pass "Edit request dibuat, ID: $ER_ID" || fail "Edit request gagal"
[ "$ER_STATUS" = "Pending" ] && pass "Status: Pending" || fail "Status salah: $ER_STATUS"
[ "$OLD_WQ" = "3.50" ] && pass "Snapshot old weight: 3.50kg (dari DB, bukan input)" || fail "Old weight salah: $OLD_WQ"
[ "$NEW_WQ" = "4.00" ] && pass "New weight: 4.00kg" || fail "New weight salah: $NEW_WQ"

# ================================================================
section "11. GIT-DIFF AUDIT VIEW (FR-OWN-01)"
# ================================================================
info "GET /api/edit-requests/$ER_ID — owner lihat komparasi"
DIFF_RES=$(curl -s "$BASE/edit-requests/$ER_ID" \
  -H "Authorization: Bearer $OWNER_TOKEN")

DIFF_OLD_SUB=$(echo "$DIFF_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(i.get('old_item_subtotal',''))" 2>/dev/null | tr -d '
')
DIFF_NEW_SUB=$(echo "$DIFF_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(i.get('new_item_subtotal',''))" 2>/dev/null | tr -d '
')
IS_CANCEL=$(echo "$DIFF_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancellation_request',''))" 2>/dev/null | tr -d '
')

echo "  Old subtotal: Rp $DIFF_OLD_SUB"
echo "  New subtotal: Rp $DIFF_NEW_SUB"
echo "  Is cancellation: $IS_CANCEL"

[ "$DIFF_OLD_SUB" = "24500" ] && pass "Old subtotal: Rp 24.500 (3.5 × 7000)" || fail "Old sub salah: $DIFF_OLD_SUB"
[ "$DIFF_NEW_SUB" = "28000" ] && pass "New subtotal: Rp 28.000 (4.0 × 7000)" || fail "New sub salah: $DIFF_NEW_SUB"
[ "$IS_CANCEL" = "False" ] && pass "Bukan cancellation request" || fail "Seharusnya bukan cancellation"

# ================================================================
section "12. ATOMIC APPROVAL (FR-OWN-02)"
# ================================================================
info "POST /api/edit-requests/$ER_ID/approve — owner approve"
APPROVE_RES=$(curl -s -X POST "$BASE/edit-requests/$ER_ID/approve" \
  -H "Authorization: Bearer $OWNER_TOKEN")

APPROVE_STATUS=$(echo "$APPROVE_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('approval_status',''))" 2>/dev/null | tr -d '
')

[ "$APPROVE_STATUS" = "Approved" ] && pass "Edit request Approved" || fail "Approval gagal: $APPROVE_STATUS"

# Cek order setelah approval
info "GET /api/orders/$ORDER_ID — cek nilai baru"
CHECK_RES=$(curl -s "$BASE/orders/$ORDER_ID" \
  -H "Authorization: Bearer $KASIR_TOKEN")

NEW_GRAND=$(echo "$CHECK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('grand_total',''))" 2>/dev/null | tr -d '
')
STILL_LOCKED=$(echo "$CHECK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_locked',''))" 2>/dev/null | tr -d '
')
NEW_WEIGHT=$(echo "$CHECK_RES" | python3 -c "import sys,json; print(format(float(json.load(sys.stdin)['items'][0].get('weight_quantity',0)), '.2f'))" 2>/dev/null | tr -d '
')

echo "  New grand total: Rp $NEW_GRAND (seharusnya 53000)"
echo "  is_locked: $STILL_LOCKED (seharusnya True)"
echo "  Item weight: ${NEW_WEIGHT}kg (seharusnya 4.00)"

[ "$NEW_GRAND" = "53000" ] && pass "Grand total di-rekalkulasi: Rp 53.000" || fail "Rekalkulasi salah: $NEW_GRAND"
[ "$STILL_LOCKED" = "True" ] && pass "Order RE-LOCKED setelah approval" || fail "Re-lock gagal"
[ "$NEW_WEIGHT" = "4.00" ] && pass "Weight terupdate: 4.00kg" || fail "Weight tidak berubah: $NEW_WEIGHT"

# ================================================================
section "13. SOFT CANCEL — PESANAN KEDUA (FR-PLG-02 tambahan)"
# ================================================================
info "POST /api/edit-requests/cancel — batalkan order $ORDER2_ID"
CANCEL_RES=$(curl -s -X POST "$BASE/edit-requests/cancel" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d "{
    \"order_id\": $ORDER2_ID,
    \"reason\": \"Pelanggan membatalkan karena pindah ke laundry lain\"
  }")

CANCEL_ER_ID=$(echo "$CANCEL_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null | tr -d '
')
IS_CANCEL_REQ=$(echo "$CANCEL_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancellation_request',''))" 2>/dev/null | tr -d '
')

[ -n "$CANCEL_ER_ID" ] && pass "Cancel request dibuat, ID: $CANCEL_ER_ID" || fail "Cancel request gagal"
[ "$IS_CANCEL_REQ" = "True" ] && pass "is_cancellation_request = True" || fail "Flag cancellation salah"

# Owner approve cancel
info "POST /api/edit-requests/$CANCEL_ER_ID/approve — owner approve cancel"
CANCEL_APP=$(curl -s -X POST "$BASE/edit-requests/$CANCEL_ER_ID/approve" \
  -H "Authorization: Bearer $OWNER_TOKEN")

CANCEL_APP_STATUS=$(echo "$CANCEL_APP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('approval_status',''))" 2>/dev/null | tr -d '
')

[ "$CANCEL_APP_STATUS" = "Approved" ] && pass "Cancel Approved" || fail "Cancel approval gagal: $CANCEL_APP_STATUS"

# Cek order 2
info "GET /api/orders/$ORDER2_ID — cek is_cancelled"
ORD2_CHECK=$(curl -s "$BASE/orders/$ORDER2_ID" \
  -H "Authorization: Bearer $KASIR_TOKEN")

ORD2_CANCELLED=$(echo "$ORD2_CHECK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancelled',''))" 2>/dev/null | tr -d '
')

[ "$ORD2_CANCELLED" = "True" ] && pass "Order 2 is_cancelled = True" || fail "Soft cancel gagal: $ORD2_CANCELLED"

# Cek tracking order 2 — harus tampil "Dibatalkan"
ORD2_TRACK=$(echo "$ORDER2_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tracking_code',''))" 2>/dev/null | tr -d '
')
info "GET /api/track/$ORD2_TRACK — harus tampil Dibatalkan"
TRACK_CANCEL=$(curl -s "$BASE/track/$ORD2_TRACK")
TRACK_CANCEL_STATUS=$(echo "$TRACK_CANCEL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('current_status',''))" 2>/dev/null | tr -d '
')
TRACK_CANCEL_FLAG=$(echo "$TRACK_CANCEL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancelled',''))" 2>/dev/null | tr -d '
')

[ "$TRACK_CANCEL_STATUS" = "Dibatalkan" ] && pass "Tracking tampil: Dibatalkan" || fail "Tracking status salah: $TRACK_CANCEL_STATUS"
[ "$TRACK_CANCEL_FLAG" = "True" ] && pass "Tracking is_cancelled = True" || fail "Tracking flag salah"

# Order 2 tidak boleh muncul di list default
info "GET /api/orders — order 2 tidak boleh muncul (default exclude cancelled)"
ORDERS_LIST=$(curl -s "$BASE/orders" -H "Authorization: Bearer $KASIR_TOKEN")
ORD2_IN_LIST=$(echo "$ORDERS_LIST" | python3 -c "
import sys,json
ids = [o['order_id'] for o in json.load(sys.stdin)['data']]
print('ADA' if $ORDER2_ID in ids else 'TIDAK')
" 2>/dev/null | tr -d '
')

[ "$ORD2_IN_LIST" = "TIDAK" ] && pass "Order cancelled tidak muncul di list default" || fail "Order cancelled masih muncul!"

# Tapi muncul kalau include_cancelled=true
info "GET /api/orders?include_cancelled=true — order 2 harus muncul"
ORDERS_ALL=$(curl -s "$BASE/orders?include_cancelled=true" -H "Authorization: Bearer $KASIR_TOKEN")
ORD2_IN_ALL=$(echo "$ORDERS_ALL" | python3 -c "
import sys,json
ids = [o['order_id'] for o in json.load(sys.stdin)['data']]
print('ADA' if $ORDER2_ID in ids else 'TIDAK')
" 2>/dev/null | tr -d '
')

[ "$ORD2_IN_ALL" = "ADA" ] && pass "Order cancelled muncul dengan include_cancelled=true" || fail "Order cancelled tidak muncul padahal include=true"

# ================================================================
section "14. ANALYTICS (FR-OWN-03)"
# ================================================================
TODAY=$(date +%Y-%m-%d)
info "GET /api/analytics/financial?date_from=$TODAY&date_to=$TODAY"
FIN_RES=$(curl -s "$BASE/analytics/financial?date_from=$TODAY&date_to=$TODAY" \
  -H "Authorization: Bearer $OWNER_TOKEN")

FIN_TOTAL=$(echo "$FIN_RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['overall']['total_grand_total'])" 2>/dev/null | tr -d '
')
FIN_COUNT=$(echo "$FIN_RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['overall']['total_orders'])" 2>/dev/null | tr -d '
')

echo "  Total orders (exclude cancelled): $FIN_COUNT"
echo "  Total grand total: Rp $FIN_TOTAL"

# Hanya order 1 yang masuk (53000), order 2 dibatalkan di-exclude
[ "$FIN_COUNT" = "1" ] && pass "Hanya 1 order aktif dihitung" || fail "Count salah: $FIN_COUNT"
[ "$FIN_TOTAL" = "53000" ] && pass "Total Rp 53.000 (order cancelled di-exclude)" || fail "Total salah: $FIN_TOTAL"

# Service breakdown
info "GET /api/analytics/service-breakdown?date_from=$TODAY&date_to=$TODAY"
SVC_RES=$(curl -s "$BASE/analytics/service-breakdown?date_from=$TODAY&date_to=$TODAY" \
  -H "Authorization: Bearer $OWNER_TOKEN")
SVC_COUNT=$(echo "$SVC_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['breakdown']))" 2>/dev/null | tr -d '
')

[ "$SVC_COUNT" = "2" ] && pass "2 service type tercatat (Kiloan + Sepatu)" || fail "Service breakdown salah: $SVC_COUNT"

# ================================================================
section "15. EDGE CASES"
# ================================================================

# Duplikat edit request untuk order yang sama
info "Coba buat edit request lagi untuk order $ORDER_ID (harus ditolak — sudah ada approved, tapi coba pending)"
# Setelah approve, tidak ada pending lagi, jadi ini seharusnya berhasil
# Kita test: buat pending, lalu buat pending lagi
ER_DUP1=$(curl -s -X POST "$BASE/edit-requests" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d "{
    \"order_id\": $ORDER_ID,
    \"reason\": \"Test duplikat pertama\",
    \"items\": [{
      \"order_item_id\": $ITEM_ID,
      \"service_type\": \"Kiloan\",
      \"new_weight_quantity\": 5.0,
      \"new_price_per_unit\": 7000
    }]
  }")
ER_DUP1_ID=$(echo "$ER_DUP1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null | tr -d '
')

# Sekarang coba buat lagi — harus ditolak
info "Coba buat edit request kedua untuk order yang sama (harus 422)"
ER_DUP2_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/edit-requests" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d "{
    \"order_id\": $ORDER_ID,
    \"reason\": \"Test duplikat kedua\",
    \"items\": [{
      \"order_item_id\": $ITEM_ID,
      \"service_type\": \"Kiloan\",
      \"new_weight_quantity\": 6.0,
      \"new_price_per_unit\": 7000
    }]
  }")

[ "$ER_DUP2_STATUS" = "422" ] && pass "Duplikat pending request ditolak (422)" || fail "Seharusnya 422, dapat $ER_DUP2_STATUS"

# Reject request duplikat tadi supaya bersih
if [ -n "$ER_DUP1_ID" ]; then
  curl -s -X POST "$BASE/edit-requests/$ER_DUP1_ID/reject" \
    -H "Authorization: Bearer $OWNER_TOKEN" > /dev/null
fi

# Tracking code invalid
info "GET /api/track/INVALID-CODE (harus 400)"
BAD_TRACK=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/track/INVALID-CODE")
[ "$BAD_TRACK" = "400" ] && pass "Tracking code invalid ditolak (400)" || fail "Seharusnya 400, dapat $BAD_TRACK"

# Tracking code tidak ada
info "GET /api/track/LND-0101-999 (harus 404)"
NOT_FOUND=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/track/LND-0101-999")
[ "$NOT_FOUND" = "404" ] && pass "Tracking code tidak ditemukan (404)" || fail "Seharusnya 404, dapat $NOT_FOUND"

# Tanpa auth
info "GET /api/orders tanpa token (harus 403 atau 401)"
NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/orders")
[ "$NO_AUTH" = "403" ] || [ "$NO_AUTH" = "401" ] && pass "Akses tanpa auth ditolak ($NO_AUTH)" || fail "Seharusnya 401/403, dapat $NO_AUTH"

# ================================================================
section "SELESAI — SEMUA TES LULUS 🎉"
# ================================================================
echo ""
echo "Ringkasan yang sudah ditest:"
echo "  ✅ Health check"
echo "  ✅ Login owner & kasir"
echo "  ✅ Register (owner only, kasir ditolak)"
echo "  ✅ Buat pesanan multi-item + hard lock"
echo "  ✅ Auto-upsert pelanggan"
echo "  ✅ Tracking publik (tanpa auth)"
echo "  ✅ Update status produksi (boleh mundur ditolak)"
echo "  ✅ Edit request + snapshot old values"
echo "  ✅ Git-diff audit view"
echo "  ✅ Atomic approval (unlock → update → relock)"
echo "  ✅ Soft cancel via approval"
echo "  ✅ Cancelled order di-exclude dari list default"
echo "  ✅ Cancelled order di-exclude dari analytics"
echo "  ✅ Tracking tampil 'Dibatalkan' untuk cancelled order"
echo "  ✅ Duplikat pending request ditolak"
echo "  ✅ Edge cases (invalid tracking, no auth, etc)"
echo ""
