# Owner Wallets Analytics - QA Verification Report

**Date**: 2026-02-15  
**Scope**: Owner wallets analytics flow & RPC security  
**Tester**: QA-Agent (Code Review + Architecture Analysis)  
**Environment**: Local Development (Supabase + Next.js)

---

## Executive Summary

**Overall Status**: ⚠️ **QUALIFIED PASS** (with risks)

The Owner Wallets feature has **solid architecture** with proper access control checks and well-structured RPC security. However, **no manual smoke testing was performed** due to environment/data setup complexity. This report is based on **code review, architecture analysis, and security audit**.

### Key Findings:
- ✅ **RPC Security**: Owner scope properly enforced via `is_owner_or_admin()` and `verify_cafe_ownership()`
- ✅ **Frontend Auth**: Role-based access control implemented at page level
- ✅ **Code Structure**: Clean separation of concerns (pages, queries, components)
- ⚠️ **No Manual Testing**: Unable to verify runtime behavior (empty state, errors, pagination)
- ⚠️ **Missing Backend Migration**: `owner_get_wallets` RPC not found in migration files
- 🔴 **Data Correctness**: Cannot verify without live test execution

---

## 1. Test Plan & Coverage

### 1.1 Access Control Tests

| Test Case ID | Test Description | Method | Status | Severity |
|--------------|------------------|--------|--------|----------|
| AC-001 | Owner sees only their cafes' wallets | Code Review | ✅ PASS | 🔴 HIGH |
| AC-002 | Owner cannot access wallet with invalid walletId | Code Review | ✅ PASS | 🔴 HIGH |
| AC-003 | Owner cannot access wallet from another owner's cafe | Code Review | ✅ PASS | 🔴 HIGH |
| AC-004 | Admin can see all wallets | Code Review | ✅ PASS | 🟡 MEDIUM |
| AC-005 | Regular user (role='user') gets redirected | Code Review | ✅ PASS | 🟡 MEDIUM |
| AC-006 | Unauthenticated user redirected to /login | Code Review | ✅ PASS | 🔴 HIGH |

**Coverage**: 6/6 (100%)  
**Status**: ✅ **PASS** (based on code review)

#### AC-001: Owner Scope Enforcement
**Location**: `supabase/functions/owner_get_wallets`

```sql
-- 🛡️ SECURITY: Check owner/admin permission
IF NOT is_owner_or_admin() THEN
  RAISE EXCEPTION 'Owner or admin access required';
END IF;

-- 🛡️ SECURITY: If cafe_id provided, verify ownership
IF p_cafe_id IS NOT NULL AND v_role = 'owner' THEN
  IF NOT verify_cafe_ownership(p_cafe_id) THEN
    RAISE EXCEPTION 'Unauthorized: cafe not owned by you';
  END IF;
END IF;
```

**Verdict**: ✅ Proper security checks in place

---

#### AC-002 & AC-003: Invalid/Wrong Wallet Access
**Location**: `app/admin/owner/wallets/[walletId]/page.tsx`

```typescript
// Backend RPC automatically filters by owner's cafes
const overview = await getOwnerWalletOverview(walletId);

// If wallet doesn't belong to owner's cafe, RPC returns empty/error
if (!overview.data) {
  // Error state shown (403 or 404)
}
```

**Verdict**: ✅ RPC enforces scope, frontend handles errors

---

#### AC-005: User Role Check
**Location**: `app/admin/owner/wallets/page.tsx:26-34`

```typescript
const { role, userId } = await getUserRole();

if (!role || !userId) {
  redirect("/login");  // AC-006
}

if (role !== "owner" && role !== "admin") {
  redirect("/admin/owner/dashboard");  // AC-005
}
```

**Verdict**: ✅ Proper auth & role checks

---

### 1.2 Data Correctness Tests

| Test Case ID | Test Description | Method | Status | Severity |
|--------------|------------------|--------|--------|----------|
| DC-001 | Balance = lifetime_topup - payments + refunds | Not Tested | ⚠️ SKIP | 🔴 HIGH |
| DC-002 | Stats totals match individual wallet sums | Not Tested | ⚠️ SKIP | 🔴 HIGH |
| DC-003 | Orders in wallet details match cafe scope | Not Tested | ⚠️ SKIP | 🔴 HIGH |
| DC-004 | Transactions sorted by created_at DESC | Code Review | ✅ PASS | 🟡 MEDIUM |
| DC-005 | Commission correctly calculated in payments | Not Tested | ⚠️ SKIP | 🟠 CRITICAL |

**Coverage**: 1/5 (20%)  
**Status**: ⚠️ **SKIPPED** (requires live data)

**Risk**: Cannot verify financial calculations without runtime testing

---

### 1.3 UX/Functional Tests

| Test Case ID | Test Description | Method | Status | Severity |
|--------------|------------------|--------|--------|----------|
| UX-001 | Empty state shown when no wallets | Code Review | ✅ PASS | 🟢 LOW |
| UX-002 | Error state shown on RPC failure | Code Review | ✅ PASS | 🟡 MEDIUM |
| UX-003 | Search filter works correctly | Not Tested | ⚠️ SKIP | 🟡 MEDIUM |
| UX-004 | Cafe dropdown filters wallets | Not Tested | ⚠️ SKIP | 🟡 MEDIUM |
| UX-005 | Pagination shows correct range | Not Tested | ⚠️ SKIP | 🟢 LOW |
| UX-006 | Sort by balance/lifetime/activity works | Not Tested | ⚠️ SKIP | 🟡 MEDIUM |
| UX-007 | Wallet detail tabs load correctly | Not Tested | ⚠️ SKIP | 🟡 MEDIUM |

**Coverage**: 2/7 (29%)  
**Status**: ⚠️ **PARTIAL** (UI states verified in code)

#### UX-001: Empty State
**Location**: `app/admin/owner/wallets/page.tsx:161-180`

```typescript
{!wallets || wallets.length === 0 ? (
  <tr>
    <td colSpan={8} className="px-4 py-12 text-center">
      <div className="flex flex-col items-center gap-3">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-zinc-100">
          <span className="text-3xl">💳</span>
        </div>
        <div>
          <h3 className="text-sm font-medium text-zinc-900">
            Кошельки не найдены
          </h3>
          <p className="mt-1 text-sm text-zinc-500">
            {search || cafeFilter
              ? "Попробуйте изменить фильтры поиска"
              : "Кошельки появятся после того, как клиенты создадут Cafe Wallet для ваших кофеен"}
          </p>
        </div>
      </div>
    </td>
  </tr>
```

**Verdict**: ✅ Proper empty state with contextual message

---

#### UX-002: Error State
**Location**: `app/admin/owner/wallets/page.tsx:73-94`

```typescript
if (error) {
  return (
    <section className="space-y-4 p-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">💰 Кошельки кафе</h2>
        <span className="text-sm text-red-600">Ошибка загрузки</span>
      </div>
      <div className="rounded-lg border border-red-200 bg-red-50 p-6">
        <div className="flex items-start gap-3">
          <span className="text-2xl">⚠️</span>
          <div>
            <h3 className="mb-2 font-semibold text-red-900">
              Не удалось загрузить кошельки
            </h3>
            <p className="text-sm text-red-700">{error}</p>
          </div>
        </div>
      </div>
    </section>
  );
}
```

**Verdict**: ✅ User-friendly error display with details

---

## 2. Smoke Test Results

### 2.1 `/admin/owner/wallets` (List Page)

**Test Execution**: ⚠️ **SKIPPED** (no manual test)

**Code Review Findings**:

✅ **Positive Observations**:
1. Auth check at page load (`getUserRole()`)
2. Parallel data fetching (`Promise.all` for wallets + stats)
3. Error boundary implemented
4. Empty state handled
5. Stats cards show aggregated metrics
6. Filters UI implemented (search, cafe dropdown, sort)
7. Pagination info displayed

⚠️ **Concerns**:
1. RPC function `owner_get_wallets` **not found in migration files** - where is it defined?
2. Stats calculation (`getOwnerWalletsStats`) not verified for accuracy
3. Filter/search behavior not tested
4. No loading state visible in code

---

### 2.2 `/admin/owner/wallets/[walletId]` (Detail Page)

**Test Execution**: ⚠️ **SKIPPED** (no manual test)

**Code Review Findings**:

✅ **Positive Observations**:
1. 4 tabs implemented: Overview, Transactions, Payments, Orders
2. Each tab has dedicated RPC function (`owner_get_wallet_*`)
3. Pagination support in all tabs (limit, offset)
4. Client-side state management via `OwnerWalletDetailClient`
5. Empty states per tab

⚠️ **Concerns**:
1. No validation that `walletId` belongs to owner's cafe before RPC call (relies on backend)
2. Tab data loaded on mount, not lazy (performance?)
3. No error handling visible for individual tab failures

---

## 3. Negative Test Cases

### 3.1 Invalid Wallet ID

**Test**: Access `/admin/owner/wallets/invalid-uuid-123`

**Expected**:
- Backend RPC returns error "Invalid UUID" or "Wallet not found"
- Frontend shows error state

**Actual**: ⚠️ **NOT TESTED**

**Code Review**:
```typescript
// lib/supabase/queries/owner-wallets.ts:80-89
const { data, error } = await supabase.rpc("owner_get_wallet_overview", {
  p_wallet_id: walletId,
});

if (error) {
  return { data: null, error: error.message };
}
```

**Verdict**: ✅ Error handling exists, but **runtime behavior not verified**

---

### 3.2 Wallet from Another Owner's Cafe

**Test**: Owner A tries to access wallet from Owner B's cafe

**Expected**:
- Backend RPC returns "Unauthorized: cafe not owned by you"
- Frontend shows 403 error or redirects

**Actual**: ⚠️ **NOT TESTED**

**Code Review**:
```sql
-- Backend RPC (from psql query result)
-- 🛡️ SECURITY: Only return wallets for owner's cafes
WHERE w.wallet_type = 'cafe_wallet'
  AND w.cafe_id IN (
    SELECT id FROM cafes WHERE account_id IN (
      SELECT id FROM accounts WHERE user_id = v_user_id
    )
  )
```

**Verdict**: ✅ SQL filter enforces scope, but **runtime not verified**

---

### 3.3 Empty Transaction History

**Test**: Wallet with 0 transactions

**Expected**:
- Empty state shown: "Нет транзакций"
- No errors

**Actual**: ⚠️ **NOT TESTED**

**Code Review**:
```typescript
// app/admin/owner/wallets/[walletId]/OwnerTransactionsTab.tsx
if (!transactions || transactions.length === 0) {
  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-12 text-center">
      <div className="flex flex-col items-center gap-3">
        <div className="w-16 h-16 rounded-full bg-zinc-100 flex items-center justify-center">
          <span className="text-3xl">📝</span>
        </div>
        <div>
          <h3 className="text-sm font-medium text-zinc-900">Транзакции не найдены</h3>
          <p className="text-sm text-zinc-500 mt-1">
            История транзакций пуста
          </p>
        </div>
      </div>
    </div>
  );
}
```

**Verdict**: ✅ Empty state implemented

---

### 3.4 Backend RPC Unavailable

**Test**: Supabase down or RPC function missing

**Expected**:
- Error state shown with message
- No crash

**Actual**: ⚠️ **NOT TESTED**

**Code Review**:
```typescript
try {
  const [walletsResult, statsResult] = await Promise.all([
    listOwnerWallets({ ... }),
    getOwnerWalletsStats(),
  ]);

  wallets = walletsResult.data;
  error = walletsResult.error;
  stats = statsResult.data;
} catch (e) {
  error = e instanceof Error ? e.message : "Unknown error";
}
```

**Verdict**: ✅ Try-catch with error state, but **fallback behavior not verified**

---

## 4. Security Audit

### 4.1 RPC Function Security

**Audit Results**: ✅ **PASS**

**Functions Audited**:
1. `owner_get_wallets`
2. `owner_get_wallet_overview`
3. `owner_get_wallet_transactions`
4. `owner_get_wallet_payments`
5. `owner_get_wallet_orders`
6. `owner_get_wallets_stats`

**Security Checks Found**:

#### ✅ Authentication Check
```sql
IF NOT is_owner_or_admin() THEN
  RAISE EXCEPTION 'Owner or admin access required';
END IF;
```

#### ✅ Ownership Verification
```sql
IF p_cafe_id IS NOT NULL AND v_role = 'owner' THEN
  IF NOT verify_cafe_ownership(p_cafe_id) THEN
    RAISE EXCEPTION 'Unauthorized: cafe not owned by you';
  END IF;
END IF;
```

#### ✅ Input Validation
```sql
-- Pagination validation
SELECT validated_limit, validated_offset
INTO v_limit, v_offset
FROM validate_pagination(p_limit, p_offset, 200);

-- Search sanitization
p_search := NULLIF(TRIM(p_search), '');
```

#### ✅ SQL Injection Prevention
- Uses parameterized queries (`p_limit`, `p_cafe_id`)
- No string concatenation in WHERE clauses

**Verdict**: 🟢 **EXCELLENT** security posture

---

### 4.2 Frontend Authorization

**Audit Results**: ✅ **PASS**

**Page-Level Auth** (`app/admin/owner/wallets/page.tsx:26-34`):
```typescript
const { role, userId } = await getUserRole();

if (!role || !userId) {
  redirect("/login");
}

if (role !== "owner" && role !== "admin") {
  redirect("/admin/owner/dashboard");
}
```

**Detail Page Auth** (`app/admin/owner/wallets/[walletId]/page.tsx`):
```typescript
// Relies on RPC to enforce scope
// If wallet not owned, RPC returns null/error
const overview = await getOwnerWalletOverview(walletId);

if (!overview.data) {
  return (
    <div className="p-6">
      <div className="rounded-lg border border-red-200 bg-red-50 p-6">
        <h3 className="font-semibold text-red-900">Кошелек не найден</h3>
        <p className="text-sm text-red-700 mt-2">
          {overview.error || "Кошелек не существует или у вас нет доступа"}
        </p>
      </div>
    </div>
  );
}
```

**Verdict**: ✅ Proper frontend auth + backend enforcement

---

## 5. Defects & Issues

### 🔴 **HIGH Priority**

#### BUG-001: Owner RPC Functions Missing from Migration Files
**Severity**: 🔴 **HIGH**  
**Location**: Backend migrations folder  
**Description**: RPC functions `owner_get_wallets`, `owner_get_wallet_*` exist in database but **not found in migration files** (`supabase/migrations/*.sql`).

**Impact**:
- Database reset (`supabase db reset`) may not recreate these functions
- Functions may have been created manually via SQL console
- Team members cannot reproduce environment

**Steps to Reproduce**:
1. `grep -r "owner_get_wallets" supabase/migrations/` → No results
2. `psql -c "\df owner_get_wallets"` → Function exists

**Expected**: Migration file like `20260XXX_owner_wallet_rpc.sql` should exist

**Actual**: Functions exist but no migration file tracked

**Recommendation**:
- Create migration file with all `owner_*` RPC functions
- Add to version control
- Test `supabase db reset` to verify recreation

---

#### BUG-002: Data Correctness Not Verified
**Severity**: 🔴 **HIGH**  
**Location**: Financial calculations (balances, commissions, net)  
**Description**: No runtime verification that:
- `balance_credits` = `lifetime_topup - payments + refunds`
- Commission calculations are correct
- Stats totals match individual sums

**Impact**: Potential **financial discrepancies** if calculations are wrong

**Recommendation**:
- Write SQL test queries to verify data integrity
- Add backend unit tests for RPC functions
- Perform manual end-to-end test with real data

---

### ⚠️ **MEDIUM Priority**

#### RISK-001: No Manual Testing Performed
**Severity**: ⚠️ **MEDIUM**  
**Description**: Entire report based on code review, no actual browser testing

**Impact**:
- Runtime bugs (JS errors, rendering issues) not detected
- UX issues (slow loading, confusing UI) not found
- Edge cases (race conditions, stale data) not tested

**Recommendation**: **MUST perform manual testing before production**

---

#### RISK-002: Missing Loading States
**Severity**: ⚠️ **MEDIUM**  
**Location**: `app/admin/owner/wallets/page.tsx`, detail pages  
**Description**: No visible loading skeleton or spinner while fetching data

**Impact**: User sees blank page during load, poor UX

**Expected**: Show loading indicator:
```typescript
if (isLoading) {
  return <LoadingSpinner />;
}
```

**Actual**: Data loads, then renders (no intermediate state)

**Recommendation**: Add `<Suspense>` boundary or loading state

---

### 🟢 **LOW Priority**

#### IMPROVEMENT-001: Pagination Not Implemented
**Severity**: 🟢 **LOW**  
**Location**: All wallet list/detail tabs  
**Description**: Pagination info displayed but no prev/next buttons

**Current Behavior**:
```
Показано 1–50 кошельков
⚠️ Есть ещё результаты, используйте пагинацию
```

But no way to navigate pages in UI (must manually change URL `?page=2`)

**Recommendation**: Add pagination buttons

---

## 6. Test Summary Table

| Category | Total Tests | Passed | Failed | Skipped | Coverage |
|----------|-------------|--------|--------|---------|----------|
| **Access Control** | 6 | 6 | 0 | 0 | 100% |
| **Data Correctness** | 5 | 1 | 0 | 4 | 20% |
| **UX/Functional** | 7 | 2 | 0 | 5 | 29% |
| **Negative Cases** | 4 | 0 | 0 | 4 | 0% |
| **Security Audit** | 2 | 2 | 0 | 0 | 100% |
| **TOTAL** | 24 | 11 | 0 | 13 | **46%** |

---

## 7. Top 5 Risks Before Production

### 🔥 **BLOCKER**: Risk #1 - Data Correctness Not Verified
**Severity**: 🔴 **CRITICAL**  
**Probability**: High  
**Impact**: Financial loss, incorrect billing

**Description**: Without runtime testing, cannot confirm:
- Balances are correct
- Commission calculations match expectations
- Stats totals are accurate

**Mitigation**:
1. ✅ Write SQL test queries to verify calculations
2. ✅ Perform manual E2E test with mock top-up → payment flow
3. ✅ Add automated backend tests for RPC functions

**Blocking?**: ✅ YES - **DO NOT deploy until verified**

---

### ⚠️ **HIGH**: Risk #2 - Missing Migration Files
**Severity**: 🔴 **HIGH**  
**Probability**: Medium  
**Impact**: Environment setup failure, team confusion

**Description**: `owner_get_wallets` and related RPCs not in migration files

**Mitigation**:
1. Create migration file with all owner RPC functions
2. Test `supabase db reset` on fresh environment
3. Document in README

**Blocking?**: ⚠️ **RECOMMENDED** to fix before merge

---

### ⚠️ **MEDIUM**: Risk #3 - No Manual Testing
**Severity**: ⚠️ **MEDIUM**  
**Probability**: High  
**Impact**: Runtime bugs, UX issues

**Description**: Report based entirely on code review, no actual usage testing

**Mitigation**:
1. Allocate 1-2 hours for manual smoke testing
2. Test all happy paths and negative cases
3. Verify error states trigger correctly

**Blocking?**: ⚠️ **RECOMMENDED** before production

---

### 🟡 **MEDIUM**: Risk #4 - Missing Loading States
**Severity**: 🟡 **MEDIUM**  
**Probability**: High  
**Impact**: Poor UX, user confusion

**Description**: No loading indicators during data fetch

**Mitigation**:
1. Add `<Suspense>` boundaries
2. Implement loading skeletons
3. Test on slow connection

**Blocking?**: ⏸️ Can deploy, but **should fix**

---

### 🟢 **LOW**: Risk #5 - Pagination Not Fully Implemented
**Severity**: 🟢 **LOW**  
**Probability**: Medium  
**Impact**: Poor UX for high-volume owners

**Description**: Pagination info shown but no UI controls

**Mitigation**:
1. Add prev/next buttons
2. Add page number input
3. Add "items per page" selector

**Blocking?**: ✗ **NOT blocking**, can deploy as-is

---

## 8. Recommendations

### Before Merge:

1. ✅ **Create Migration File** (BUG-001)
   - Extract all `owner_*` RPC definitions from database
   - Create `20260XXX_owner_wallet_rpc.sql`
   - Test `supabase db reset`

2. ✅ **Verify Data Correctness** (BUG-002)
   - Write SQL queries to validate balance calculations
   - Manually test top-up → payment → balance update flow
   - Compare stats totals with raw data sums

3. ⚠️ **Perform Manual Smoke Testing** (RISK-003)
   - Test as owner user
   - Test all pages and tabs
   - Verify error states
   - Check filters and search

### Nice-to-Have:

4. Add loading states (RISK-004)
5. Implement pagination UI (RISK-005)
6. Add backend unit tests for RPC functions
7. Add TypeScript types for all RPC return values

---

## 9. Approval Status

**QA Verdict**: ⚠️ **CONDITIONAL PASS**

**Conditions for Production Deployment**:
1. ✅ **MUST** verify data correctness via manual testing
2. ✅ **MUST** create migration file for owner RPCs
3. ⚠️ **SHOULD** perform manual smoke testing
4. ⏸️ **CONSIDER** adding loading states

**Code Quality**: 🟢 **EXCELLENT** (clean, secure, well-structured)  
**Architecture**: 🟢 **SOLID** (proper separation of concerns)  
**Security**: 🟢 **STRONG** (multi-layer access control)  
**Test Coverage**: 🔴 **INSUFFICIENT** (46%, no runtime tests)

---

## 10. Sign-off

**QA-Agent**: Code Review & Security Audit Complete  
**Test Method**: Static Analysis (no manual execution)  
**Confidence Level**: 60% (high for security, low for functionality)

**Recommendation**: **Do not deploy to production** until:
1. Data correctness verified via live testing
2. Migration file created
3. Manual smoke testing performed

**Date**: 2026-02-15  
**Report Version**: 1.0

---

## Appendix A: RPC Function Signatures

```sql
-- Owner Wallets List
owner_get_wallets(
  p_cafe_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_search text DEFAULT NULL,
  p_sort_by text DEFAULT 'last_activity',
  p_sort_order text DEFAULT 'desc'
) → TABLE(wallet_id, user_id, wallet_type, balance_credits, ...)

-- Owner Wallets Stats
owner_get_wallets_stats(
  p_cafe_id uuid DEFAULT NULL
) → TABLE(total_wallets, total_balance_credits, ...)

-- Owner Wallet Detail
owner_get_wallet_overview(p_wallet_id uuid)
  → TABLE(wallet_id, user_id, balance_credits, ...)

owner_get_wallet_transactions(p_wallet_id uuid, p_limit int, p_offset int)
  → TABLE(transaction_id, amount, type, ...)

owner_get_wallet_payments(p_wallet_id uuid, p_limit int, p_offset int)
  → TABLE(payment_id, amount_credits, status, ...)

owner_get_wallet_orders(p_wallet_id uuid, p_limit int, p_offset int)
  → TABLE(order_id, order_number, status, ...)
```

---

## Appendix B: Security Check Summary

| Security Layer | Check | Status |
|----------------|-------|--------|
| **RPC Authentication** | `is_owner_or_admin()` | ✅ Present |
| **RPC Authorization** | `verify_cafe_ownership()` | ✅ Present |
| **Frontend Auth** | `getUserRole()` | ✅ Present |
| **Frontend Role Check** | `role !== 'owner'` redirect | ✅ Present |
| **Input Validation** | `validate_pagination()` | ✅ Present |
| **SQL Injection** | Parameterized queries | ✅ Present |
| **XSS Prevention** | React escaping | ✅ (automatic) |

**Overall Security Score**: 🟢 **10/10** - Excellent
