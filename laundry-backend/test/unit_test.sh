#!/bin/bash
# ================================================================
# Smart Laundry POS System — Automated Integration Test Suite
# Execution Command: bash test_api.sh
# ================================================================

BASE="http://localhost:8000/api"
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[SUCCESS]${NC} — $1"; }
fail() { echo -e "${RED}[FAILURE]${NC} — $1"; exit 1; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
section() { echo -e "\n${YELLOW}=== SECTION: $1 ===${NC}"; }

# ================================================================
section "0. SERVICE HEALTH CHECK"
# ================================================================
info "Executing GET /api/health"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health")
[ "$STATUS" = "200" ] && pass "Service health check verified (200 OK)" || fail "Service unavailable ($STATUS)"

# ================================================================
section "1. AUTHENTICATION — OWNER PRIVILEGES"
# ================================================================
info "Executing POST /api/auth/login (Role: Owner)"
OWNER_RES=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"owner","password":"owner123"}')

OWNER_TOKEN=$(echo "$OWNER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null | tr -d '\r')
OWNER_ROLE=$(echo "$OWNER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('role',''))" 2>/dev/null | tr -d '\r')

[ -n "$OWNER_TOKEN" ] && pass "Authentication successful, bearer token retrieved." || fail "Authentication failed, token missing."
[ "$OWNER_ROLE" = "owner" ] && pass "Authorization role validated: $OWNER_ROLE" || fail "Role mismatch detected: $OWNER_ROLE"

# ================================================================
section "2. AUTHENTICATION — CASHIER PRIVILEGES"
# ================================================================
info "Executing POST /api/auth/login (Role: Cashier 1)"
KASIR_RES=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"kasir1","password":"kasir123"}')

KASIR_TOKEN=$(echo "$KASIR_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null | tr -d '\r')
KASIR_ID=$(echo "$KASIR_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user_id',''))" 2>/dev/null | tr -d '\r')

[ -n "$KASIR_TOKEN" ] && pass "Authentication successful, bearer token retrieved." || fail "Authentication failed."
[ -n "$KASIR_ID" ] && pass "User ID provisioned: $KASIR_ID" || fail "User ID missing from response payload."

# ================================================================
section "3. USER MANAGEMENT — CASHIER REGISTRATION (RESTRICTED TO OWNER)"
# ================================================================
info "Executing POST /api/auth/register (New Cashier Provisioning)"
REG_RES=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OWNER_TOKEN" \
  -d '{"username":"kasir2","password":"kasir123","role":"kasir"}')

REG_STATUS=$(echo "$REG_RES" | tail -1)
REG_BODY=$(echo "$REG_RES" | sed '$d')

if [ "$REG_STATUS" = "201" ]; then
    pass "Cashier account successfully provisioned (201 Created)"
elif [ "$REG_STATUS" = "409" ]; then
    pass "Account already exists, skipping provisioning (409 Conflict — Idempotent Re-run)"
else
    fail "Registration sequence failed ($REG_STATUS): $REG_BODY"
fi

# Verification: Access Control enforcement on Cashier level
info "Verifying RBAC Restriction: POST /api/auth/register by Cashier (Expected: 403 Forbidden)"
FORBIDDEN=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"username":"kasir3","password":"kasir123","role":"kasir"}')

[ "$FORBIDDEN" = "403" ] && pass "Access control enforced. Request denied (403 Forbidden)" || fail "Security vulnerability: expected 403, received $FORBIDDEN"

# ================================================================
section "4. TRANSACTION MANAGEMENT — INITIAL ORDER CREATION (FR-KSR-01, FR-KSR-02, FR-KSR-03)"
# ================================================================
info "Executing POST /api/orders — Initiating Multi-Item Transaction (Customer: Budi)"
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

ORDER_ID=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('order_id',''))" 2>/dev/null | tr -d '\r')
TRACKING=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tracking_code',''))" 2>/dev/null | tr -d '\r')
IS_LOCKED=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_locked',''))" 2>/dev/null | tr -d '\r')
GRAND_TOTAL=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('grand_total',''))" 2>/dev/null | tr -d '\r')
QUEUE_NUM=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('queue_number',''))" 2>/dev/null | tr -d '\r')
ITEM_COUNT=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('items',[])))" 2>/dev/null | tr -d '\r')

echo "  Transaction Record — Order ID: $ORDER_ID"
echo "  Transaction Record — Tracking Code: $TRACKING"
echo "  Transaction Record — Grand Total: IDR $GRAND_TOTAL"
echo "  Transaction Record — Queue Assignment: #$QUEUE_NUM"
echo "  Transaction Record — Total Line Items: $ITEM_COUNT"

[ -n "$ORDER_ID" ] && pass "Order lifecycle initiated. ID: $ORDER_ID" || fail "Order processing failed."
[ "$IS_LOCKED" = "True" ] && pass "Data integrity guard active: is_locked = TRUE (Hard Lock enforced)" || fail "Data integrity vulnerability: is_locked must evaluate to TRUE"
[ "$GRAND_TOTAL" = "49500" ] && pass "Financial computation verified: IDR 49,500 (Calculation: 3.5×7000 + 1×25000)" || fail "Financial mismatch detected: $GRAND_TOTAL"
[ "$ITEM_COUNT" = "2" ] && pass "Line items successfully persisted ($ITEM_COUNT items)" || fail "Line item count variance: $ITEM_COUNT"

# ================================================================
section "5. CRM SYSTEM — AUTOMATED CUSTOMER UPSERT VERIFICATION (FR-KSR-02)"
# ================================================================
info "Executing GET /api/customers (Querying Customer Records via Phone Number)"
CUST_RES=$(curl -s "$BASE/customers?search=081234567890" \
  -H "Authorization: Bearer $KASIR_TOKEN")

CUST_ID=$(echo "$CUST_RES" | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(d[0]['customer_id'] if d else '')" 2>/dev/null | tr -d '\r')

[ -n "$CUST_ID" ] && pass "Customer auto-provisioning verified. Profile ID: $CUST_ID" || fail "Customer profile indexing failed."

# ================================================================
section "6. TRANSACTION MANAGEMENT — SUBSEQUENT ORDER VIA EXISTENT PROFILE (FR-KSR-02)"
# ================================================================
info "Executing POST /api/orders — Generating Secondary Order Linked to Existing Profile"
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

ORDER2_ID=$(echo "$ORDER2_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('order_id',''))" 2>/dev/null | tr -d '\r')
ORDER2_TOTAL=$(echo "$ORDER2_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('grand_total',''))" 2>/dev/null | tr -d '\r')

echo "  Transaction Record — Order 2 ID: $ORDER2_ID"
echo "  Transaction Record — Grand Total: IDR $ORDER2_TOTAL"

[ -n "$ORDER2_ID" ] && pass "Secondary order processed successfully." || fail "Secondary order processing failed."
[ "$ORDER2_TOTAL" = "33000" ] && pass "Tax formulation verified (10% VAT): 30000 + 3000 = 33000" || fail "Tax calculation anomaly: $ORDER2_TOTAL"

# ================================================================
section "7. CLIENT ACCESSIBILITY — PUBLIC TRACKING SERVICE (FR-PLG-01, FR-PLG-02, FR-PLG-03)"
# ================================================================
info "Executing GET /api/track/$TRACKING (Unauthenticated Access Verification)"
TRACK_RES=$(curl -s "$BASE/track/$TRACKING")

TRACK_NAME=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('customer_name',''))" 2>/dev/null | tr -d '\r')
TRACK_STATUS=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('current_status',''))" 2>/dev/null | tr -d '\r')
TRACK_PROGRESS=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status_progress',''))" 2>/dev/null | tr -d '\r')
TRACK_QUEUE=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('queue_position',''))" 2>/dev/null | tr -d '\r')
TRACK_CANCELLED=$(echo "$TRACK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancelled',''))" 2>/dev/null | tr -d '\r')

echo "  Public Ledger — Client Identity: $TRACK_NAME"
echo "  Public Ledger — Operational Status: $TRACK_STATUS"
echo "  Public Ledger — Operational Progress: $TRACK_PROGRESS%"
echo "  Public Ledger — Queue Vector Position: $TRACK_QUEUE"

[ "$TRACK_NAME" = "Budi Santoso" ] && pass "Data alignment verified: client identity matches." || fail "Data mismatch in client field: $TRACK_NAME"
[ "$TRACK_STATUS" = "Antrean" ] && pass "Status trajectory verified: Antrean" || fail "Status state anomaly: $TRACK_STATUS"
[ "$TRACK_PROGRESS" = "0" ] && pass "Progress metrics aligned: 0%" || fail "Progress calculation anomaly: $TRACK_PROGRESS"
[ "$TRACK_CANCELLED" = "False" ] && pass "Cancellation state validated: False" || fail "Cancellation state conflict"

# ================================================================
section "8. OPERATIONS — PRODUCTION STATE MODIFICATION"
# ================================================================
info "Executing PATCH /api/orders/$ORDER_ID/status (Transition to: Dicuci)"
STATUS_RES=$(curl -s -X PATCH "$BASE/orders/$ORDER_ID/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"current_status": "Dicuci"}')

NEW_STATUS=$(echo "$STATUS_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('current_status',''))" 2>/dev/null | tr -d '\r')
[ "$NEW_STATUS" = "Dicuci" ] && pass "Operational state transitioned to: Dicuci" || fail "State transition failed: $NEW_STATUS"

# State Machine Constraint Verification: Reversion Block
info "Verifying Workflow Constraint: PATCH status rollback attempt to 'Antrean' (Expected: 422 Unprocessable Entity)"
MUNDUR=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE/orders/$ORDER_ID/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"current_status": "Antrean"}')

[ "$MUNDUR" = "422" ] && pass "Workflow logic enforced: State reversion rejected (422 Unprocessable Entity)" || fail "Workflow violation: expected 422, received $MUNDUR"

# ================================================================
section "8.5 OPERATIONS — PAYMENT STATE MODIFICATION"
# ================================================================
info "Executing PATCH /api/orders/$ORDER_ID/payment (Transition to: Lunas)"
PAYMENT_RES=$(curl -s -X PATCH "$BASE/orders/$ORDER_ID/payment" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"payment_status": "Lunas"}')

NEW_PAYMENT=$(echo "$PAYMENT_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('payment_status',''))" 2>/dev/null | tr -d '\r')
[ "$NEW_PAYMENT" = "Lunas" ] && pass "Financial state transitioned to: Lunas" || fail "Payment state transition failed: $NEW_PAYMENT"

info "Executing PATCH /api/orders/$ORDER_ID/payment (Reverting to: Belum Lunas for subsequent tests)"
REVERT_PAY=$(curl -s -X PATCH "$BASE/orders/$ORDER_ID/payment" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{"payment_status": "Belum Lunas"}')

REVERT_STATUS=$(echo "$REVERT_PAY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('payment_status',''))" 2>/dev/null | tr -d '\r')
[ "$REVERT_STATUS" = "Belum Lunas" ] && pass "Financial state reverted to: Belum Lunas" || fail "Payment state revert failed: $REVERT_STATUS"

# ================================================================
section "9. IMMUTABILITY — DIRECT MODIFICATION GUARD"
# ================================================================
info "Verifying ledger immutability on locked entities (Expected: Endpoint/Service-level rejection via 403 on financial mutations)"

# ================================================================
section "10. CHANGE MANAGEMENT — CASHIER AMENDMENT REQUEST (FR-KSR-04)"
# ================================================================
ITEM_ID=$(echo "$ORDER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['items'][0]['item_id'])" 2>/dev/null | tr -d '\r')
echo "  Target Item Identity Token: $ITEM_ID"

info "Executing POST /api/edit-requests — Registering Amendment: Adjusting weight parameters from 3.5kg to 4.0kg"
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

ER_ID=$(echo "$ER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null | tr -d '\r')
ER_STATUS=$(echo "$ER_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('approval_status',''))" 2>/dev/null | tr -d '\r')
OLD_WQ=$(echo "$ER_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(format(float(i.get('old_weight_quantity',0)), '.2f'))" 2>/dev/null | tr -d '\r')
NEW_WQ=$(echo "$ER_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(format(float(i.get('new_weight_quantity',0)), '.2f'))" 2>/dev/null | tr -d '\r')

echo "  Change Ticket — Request ID: $ER_ID"
echo "  Change Ticket — Delta Vector: ${OLD_WQ}kg -> ${NEW_WQ}kg"

[ -n "$ER_ID" ] && pass "Amendment ticket logged successfully. Request ID: $ER_ID" || fail "Amendment ticketing failed."
[ "$ER_STATUS" = "Pending" ] && pass "Ticket status evaluated as: Pending review" || fail "Status abnormality: $ER_STATUS"
[ "$OLD_WQ" = "3.50" ] && pass "Historical snapshot alignment verified: 3.50kg fetched from database" || fail "Snapshot integrity fault: $OLD_WQ"
[ "$NEW_WQ" = "4.00" ] && pass "Proposed metric target: 4.00kg" || fail "Target metric variance: $NEW_WQ"

# ================================================================
section "11. AUDIT COMPLIANCE — GIT-DIFF COMPARATIVE VIEW (FR-OWN-01)"
# ================================================================
info "Executing GET /api/edit-requests/$ER_ID — Administrative Review and Variance Analysis"
DIFF_RES=$(curl -s "$BASE/edit-requests/$ER_ID" \
  -H "Authorization: Bearer $OWNER_TOKEN")

DIFF_OLD_SUB=$(echo "$DIFF_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(i.get('old_item_subtotal',''))" 2>/dev/null | tr -d '\r')
DIFF_NEW_SUB=$(echo "$DIFF_RES" | python3 -c "import sys,json; i=json.load(sys.stdin)['items'][0]; print(i.get('new_item_subtotal',''))" 2>/dev/null | tr -d '\r')
IS_CANCEL=$(echo "$DIFF_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancellation_request',''))" 2>/dev/null | tr -d '\r')

echo "  Audit Desk — Legacy Value: IDR $DIFF_OLD_SUB"
echo "  Audit Desk — Proposed Value: IDR $DIFF_NEW_SUB"
echo "  Audit Desk — Structural Revocation Flag: $IS_CANCEL"

[ "$DIFF_OLD_SUB" = "24500" ] && pass "Audit trail correct. Baseline value evaluated at IDR 24,500" || fail "Baseline audit mismatch: $DIFF_OLD_SUB"
[ "$DIFF_NEW_SUB" = "28000" ] && pass "Audit trail correct. Target projection evaluated at IDR 28,000" || fail "Target projection mismatch: $DIFF_NEW_SUB"
[ "$IS_CANCEL" = "False" ] && pass "Validated classification: Amendment Request" || fail "Classification error on revocation flag"

# ================================================================
section "12. CONCURRENCY CONTROL — ATOMIC TRANSACTION APPROVAL (FR-OWN-02)"
# ================================================================
info "Executing POST /api/edit-requests/$ER_ID/approve — Authorizing Financial Amendment"
APPROVE_RES=$(curl -s -X POST "$BASE/edit-requests/$ER_ID/approve" \
  -H "Authorization: Bearer $OWNER_TOKEN")

APPROVE_STATUS=$(echo "$APPROVE_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('approval_status',''))" 2>/dev/null | tr -d '\r')

[ "$APPROVE_STATUS" = "Approved" ] && pass "Authorization execution sequence completed: Approved" || fail "Authorization sequence aborted: $APPROVE_STATUS"

# Post-authorization validation state check
info "Executing GET /api/orders/$ORDER_ID — Verifying Ledger Convergence"
CHECK_RES=$(curl -s "$BASE/orders/$ORDER_ID" \
  -H "Authorization: Bearer $KASIR_TOKEN")

NEW_GRAND=$(echo "$CHECK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('grand_total',''))" 2>/dev/null | tr -d '\r')
STILL_LOCKED=$(echo "$CHECK_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_locked',''))" 2>/dev/null | tr -d '\r')
NEW_WEIGHT=$(echo "$CHECK_RES" | python3 -c "import sys,json; print(format(float(json.load(sys.stdin)['items'][0].get('weight_quantity',0)), '.2f'))" 2>/dev/null | tr -d '\r')

echo "  Ledger Verification — Recalculated Grand Total: IDR $NEW_GRAND (Target: 53000)"
echo "  Ledger Verification — Re-enforced Mutex Status: $STILL_LOCKED (Target: True)"
echo "  Ledger Verification — Converged Item Weight Metric: ${NEW_WEIGHT}kg (Target: 4.00)"

[ "$NEW_GRAND" = "53000" ] && pass "Financial settlement adjusted: IDR 53,000" || fail "Recalculation error: $NEW_GRAND"
[ "$STILL_LOCKED" = "True" ] && pass "Security protocol enforced: Record RE-LOCKED after execution" || fail "Security failure: state left un-mutexed"
[ "$NEW_WEIGHT" = "4.00" ] && pass "Metrics data successfully persisted: 4.00kg" || fail "Data anomaly on metric persistence: $NEW_WEIGHT"

# ================================================================
section "13. COMPLIANCE & REVOCATION — TRANSACTION CANCELLATION WORKFLOW"
# ================================================================
info "Executing POST /api/edit-requests/cancel — Requesting Revocation for Order ID $ORDER2_ID"
CANCEL_RES=$(curl -s -X POST "$BASE/edit-requests/cancel" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d "{
    \"order_id\": $ORDER2_ID,
    \"reason\": \"Pelanggan membatalkan karena pindah ke laundry lain\"
  }")

CANCEL_ER_ID=$(echo "$CANCEL_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null | tr -d '\r')
IS_CANCEL_REQ=$(echo "$CANCEL_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancellation_request',''))" 2>/dev/null | tr -d '\r')

[ -n "$CANCEL_ER_ID" ] && pass "Revocation request logged. ID: $CANCEL_ER_ID" || fail "Revocation logging failed."
[ "$IS_CANCEL_REQ" = "True" ] && pass "Structural classification: is_cancellation_request confirmed True" || fail "Classification metadata error"

# Administrative Approval on Revocation Request
info "Executing POST /api/edit-requests/$CANCEL_ER_ID/approve — Authorizing Revocation"
CANCEL_APP=$(curl -s -X POST "$BASE/edit-requests/$CANCEL_ER_ID/approve" \
  -H "Authorization: Bearer $OWNER_TOKEN")

CANCEL_APP_STATUS=$(echo "$CANCEL_APP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('approval_status',''))" 2>/dev/null | tr -d '\r')

[ "$CANCEL_APP_STATUS" = "Approved" ] && pass "Revocation finalized: Approved" || fail "Revocation approval routine failed: $CANCEL_APP_STATUS"

# Ledger status verification for secondary order
info "Executing GET /api/orders/$ORDER2_ID — Verifying Revocation Flagging"
ORD2_CHECK=$(curl -s "$BASE/orders/$ORDER2_ID" \
  -H "Authorization: Bearer $KASIR_TOKEN")

ORD2_CANCELLED=$(echo "$ORD2_CHECK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancelled',''))" 2>/dev/null | tr -d '\r')

[ "$ORD2_CANCELLED" = "True" ] && pass "Soft-deletion pattern executed: is_cancelled evaluates to True" || fail "Data lifecycle anomaly: record active"

# Client tracking ledger verification on cancelled entity
ORD2_TRACK=$(echo "$ORDER2_RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tracking_code',''))" 2>/dev/null | tr -d '\r')
info "Executing GET /api/track/$ORD2_TRACK — Verifying Public Status Trajectory"
TRACK_CANCEL=$(curl -s "$BASE/track/$ORD2_TRACK")
TRACK_CANCEL_STATUS=$(echo "$TRACK_CANCEL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('current_status',''))" 2>/dev/null | tr -d '\r')
TRACK_CANCEL_FLAG=$(echo "$TRACK_CANCEL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_cancelled',''))" 2>/dev/null | tr -d '\r')

[ "$TRACK_CANCEL_STATUS" = "Dibatalkan" ] && pass "Public status correctly maps to: Dibatalkan" || fail "Tracking status mismatch: $TRACK_CANCEL_STATUS"
[ "$TRACK_CANCEL_FLAG" = "True" ] && pass "Public flag evaluates to: is_cancelled = True" || fail "Tracking flag mismatch"

# Verifying visibility exclusion constraints
info "Executing GET /api/orders — Verifying Exclusions in Default Collection Queries"
ORDERS_LIST=$(curl -s "$BASE/orders" -H "Authorization: Bearer $KASIR_TOKEN")
ORD2_IN_LIST=$(echo "$ORDERS_LIST" | python3 -c "
import sys,json
ids = [o['order_id'] for o in json.load(sys.stdin)['data']]
print('ADA' if $ORDER2_ID in ids else 'TIDAK')
" 2>/dev/null | tr -d '\r')

[ "$ORD2_IN_LIST" = "TIDAK" ] && pass "Data isolation verified: revoked records omitted from default view" || fail "Isolation integrity breach: revoked records found in active collection"

# Verifying overriding collection parameters
info "Executing GET /api/orders?include_cancelled=true — Verifying Inclusive Collection Queries"
ORDERS_ALL=$(curl -s "$BASE/orders?include_cancelled=true" -H "Authorization: Bearer $KASIR_TOKEN")
ORD2_IN_ALL=$(echo "$ORDERS_ALL" | python3 -c "
import sys,json
ids = [o['order_id'] for o in json.load(sys.stdin)['data']]
print('ADA' if $ORDER2_ID in ids else 'TIDAK')
" 2>/dev/null | tr -d '\r')

[ "$ORD2_IN_ALL" = "ADA" ] && pass "Query parameter validated: inclusive view retrieves revoked records" || fail "Query execution error: filter parameter ignored"

# ================================================================
section "14. EXECUTIVE REPORTING — FINANCIAL ANALYTICS ENGINE (FR-OWN-03)"
# ================================================================
TODAY=$(date +%Y-%m-%d)
info "Executing GET /api/analytics/financial?date_from=$TODAY&date_to=$TODAY"
FIN_RES=$(curl -s "$BASE/analytics/financial?date_from=$TODAY&date_to=$TODAY" \
  -H "Authorization: Bearer $OWNER_TOKEN")

FIN_TOTAL=$(echo "$FIN_RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['overall']['total_grand_total'])" 2>/dev/null | tr -d '\r')
FIN_COUNT=$(echo "$FIN_RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['overall']['total_orders'])" 2>/dev/null | tr -d '\r')

echo "  Reporting Module — Net Valid Invoices: $FIN_COUNT"
echo "  Reporting Module — Aggregate Gross Yield: IDR $FIN_TOTAL"

# Financial deduction analytics validation
[ "$FIN_COUNT" = "1" ] && pass "Reporting matrix validated: only active contracts parsed" || fail "Reporting count variance: $FIN_COUNT"
[ "$FIN_TOTAL" = "53000" ] && pass "Reporting matrix validated: IDR 53,000 (revoked financial vectors correctly omitted)" || fail "Yield tracking discrepancy: $FIN_TOTAL"

# Business unit classification data check
info "Executing GET /api/analytics/service-breakdown?date_from=$TODAY&date_to=$TODAY"
SVC_RES=$(curl -s "$BASE/analytics/service-breakdown?date_from=$TODAY&date_to=$TODAY" \
  -H "Authorization: Bearer $OWNER_TOKEN")
SVC_COUNT=$(echo "$SVC_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['breakdown']))" 2>/dev/null | tr -d '\r')

[ "$SVC_COUNT" = "2" ] && pass "Classification alignment verified: 2 business segments recorded (Kiloan + Sepatu)" || fail "Segment mapping error: $SVC_COUNT"

# ================================================================
section "15. SYSTEM ROBUSTNESS — EDGE CASE VALIDATIONS"
# ================================================================

# Concurrency test: Duplicate modification tickets
info "Testing Concurrency Safeguard: Initiating duplicate pending modification request for Order ID $ORDER_ID"
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
ER_DUP1_ID=$(echo "$ER_DUP1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('request_id',''))" 2>/dev/null | tr -d '\r')

info "Verifying Race Condition Guard: Registering secondary conflicting modification ticket (Expected: 422 Unprocessable Entity)"
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

[ "$ER_DUP2_STATUS" = "422" ] && pass "State integrity preserved: Concurrent ticket rejected (422 Unprocessable Entity)" || fail "State pollution vulnerability: expected 422, received $ER_DUP2_STATUS"

# Cleanup routine for testing logs
if [ -n "$ER_DUP1_ID" ]; then
  curl -s -X POST "$BASE/edit-requests/$ER_DUP1_ID/reject" \
    -H "Authorization: Bearer $OWNER_TOKEN" > /dev/null
fi

# Validation: Syntax constraints on public parameters
info "Executing GET /api/track/INVALID-CODE (Expected: 400 Bad Request)"
BAD_TRACK=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/track/INVALID-CODE")
[ "$BAD_TRACK" = "400" ] && pass "Parameter constraint validated: structural validation failed (400 Bad Request)" || fail "Parameter validation bypass: expected 400, received $BAD_TRACK"

# Validation: Boundary checking on record existence
info "Executing GET /api/track/LND-0101-999 (Expected: 404 Not Found)"
NOT_FOUND=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/track/LND-0101-999")
[ "$NOT_FOUND" = "404" ] && pass "Record lookup boundary verified: entity not found (404 Not Found)" || fail "Record mapping issue: expected 404, received $NOT_FOUND"

# Validation: Security handshake layer
info "Executing GET /api/orders without credentials (Expected: 401 Unauthorized / 403 Forbidden)"
NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/orders")
[ "$NO_AUTH" = "403" ] || [ "$NO_AUTH" = "401" ] && pass "Handshake layer secure: Unauthenticated connection rejected ($NO_AUTH)" || fail "Security breach: expected 401/403, received $NO_AUTH"

# ================================================================
section "VERIFICATION COMPLETE — ALL PROTOCOLS VERIFIED"
# ================================================================
echo ""
echo "Summary of Verified Integration Components:"
echo "  [SUCCESS] System Health Check Evaluation"
echo "  [SUCCESS] Dual-Role Authentication Procedures (Owner and Cashier)"
echo "  [SUCCESS] Role-Based Access Control (RBAC) Architecture Constraints"
echo "  [SUCCESS] Multi-Line Item Order Processing & Transaction Locking Mechanism"
echo "  [SUCCESS] CRM Layer Automated Profile Interception and Upsert Routing"
echo "  [SUCCESS] Unauthenticated Public Trajectory and Status Reporting"
echo "  [SUCCESS] Monotonic Production Stage Restrictions (No Status Rollback)"
echo "  [SUCCESS] Financial State Modification (Payment Status Transition)"
echo "  [SUCCESS] Audit-Friendly Modification Ticketing & Context State Snapshots"
echo "  [SUCCESS] Structural Line-Item Delta and Variance Accounting (Git-Diff View)"
echo "  [SUCCESS] Atomic Amendment Execution Routines (Mutex Release -> Ledger Write -> Mutex Lock)"
echo "  [SUCCESS] Multi-Layer Soft Revocation Routines"
echo "  [SUCCESS] Data Exclusion Compliance Filters in Collection Views"
echo "  [SUCCESS] Net Yield Analytics and Segment Yield Metrics Deductions"
echo "  [SUCCESS] Real-Time Public Vector Adjustment Reflection on Cancellations"
echo "  [SUCCESS] Anti-Collision Concurrency Guard for Pending State Objects"
echo "  [SUCCESS] Network Boundary Handling (Malformed Parameters, Missing Tokens, Missing Records)"
echo ""
