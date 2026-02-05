# Security Fix: Wallets RLS Policy Hardening

## 🔒 Priority: P0 (Critical Security)

## Problem

The original RLS policy for `public.wallets` allowed users to UPDATE their own wallet records:

```sql
create policy "Own wallets update" on public.wallets
  for update using (auth.uid() = user_id);
```

**Security Risk**: This policy allowed authenticated users to directly update their wallet balance via raw SQL queries or REST API, bypassing business logic and enabling:
- Arbitrary balance increases
- Fraudulent transactions
- Bypassing payment processing

## Solution

### 1. Removed UPDATE Policy

**File**: `supabase/migrations/20260120120000_mvp_coffee.sql` (lines 200-205)

**Before**:
```sql
if not exists (
  select 1 from pg_policies where schemaname='public' and tablename='wallets' and policyname='Own wallets update'
) then
  create policy "Own wallets update" on public.wallets
    for update using (auth.uid() = user_id);
end if;
```

**After**:
```sql
-- REMOVED: "Own wallets update" policy
-- Users can only SELECT their wallets, not UPDATE balance directly.
-- Balance updates must be done through secure RPC functions or backend triggers.
```

### 2. Created Cleanup Migration

**File**: `supabase/migrations/20260205000001_fix_wallets_rls_security.sql`

Drops the policy from existing databases and adds documentation comment.

## Current Permissions

### ✅ Allowed Operations

| Operation | Policy | Description |
|-----------|--------|-------------|
| SELECT | "Own wallets select" | Users can view their own wallet balances |
| INSERT | "Own wallets insert" | Users can create new wallets (validated by check constraint) |

### ❌ Blocked Operations

| Operation | Reason |
|-----------|--------|
| UPDATE | No policy exists - all direct updates blocked |
| DELETE | No policy exists - prevents accidental/malicious wallet deletion |

## Secure Balance Update Flow

### Method 1: RPC Functions (Recommended)

Create secure RPC functions with business logic:

```sql
create or replace function public.top_up_wallet(
  p_wallet_id uuid,
  p_amount int,
  p_payment_method text
)
returns public.wallets
language plpgsql
security definer -- Runs with elevated privileges
as $$
declare
  v_wallet public.wallets;
begin
  -- Verify ownership
  select * into v_wallet
  from public.wallets
  where id = p_wallet_id and user_id = auth.uid();
  
  if not found then
    raise exception 'Wallet not found or access denied';
  end if;
  
  -- Validate payment (integrate with payment provider)
  -- perform validate_payment(p_payment_method, p_amount);
  
  -- Update balance atomically
  update public.wallets
  set credits_balance = credits_balance + p_amount,
      updated_at = now()
  where id = p_wallet_id
  returning * into v_wallet;
  
  return v_wallet;
end;
$$;

grant execute on function public.top_up_wallet(uuid, int, text) to authenticated;
```

### Method 2: Backend Triggers

For automated balance updates (e.g., order processing):

```sql
create or replace function public.process_order_payment()
returns trigger
language plpgsql
security definer
as $$
begin
  -- Deduct from wallet
  update public.wallets
  set credits_balance = credits_balance - NEW.paid_credits,
      bonus_balance = bonus_balance - NEW.bonus_used
  where id = NEW.wallet_id;
  
  return NEW;
end;
$$;

create trigger order_payment_trigger
  after insert on public.orders
  for each row
  execute function public.process_order_payment();
```

### Method 3: Service Role (Backend Only)

For admin/backend operations, use service role key:

```typescript
// Backend API with service role key
const { data, error } = await supabaseAdmin
  .from('wallets')
  .update({ credits_balance: newBalance })
  .eq('id', walletId);
```

## Verification Checklist

- [x] Removed UPDATE policy from `20260120120000_mvp_coffee.sql`
- [x] Created cleanup migration `20260205000001_fix_wallets_rls_security.sql`
- [x] Added security documentation
- [ ] Review all RPC functions that update wallet balance
- [ ] Ensure payment processing uses secure functions
- [ ] Test that direct UPDATE attempts fail for authenticated users
- [ ] Update admin panel to use service role for admin operations

## Testing

### Test 1: Direct UPDATE Should Fail

```sql
-- As authenticated user
update public.wallets 
set credits_balance = 999999 
where user_id = auth.uid();

-- Expected: Policy violation error
-- Error: new row violates row-level security policy for table "wallets"
```

### Test 2: SELECT Should Work

```sql
-- As authenticated user
select * from public.wallets where user_id = auth.uid();

-- Expected: Returns user's wallets
```

### Test 3: INSERT Should Work (Wallet Creation)

```sql
-- As authenticated user
insert into public.wallets (user_id, type, credits_balance, bonus_balance)
values (auth.uid(), 'citypass', 0, 0);

-- Expected: Success (if constraints pass)
```

## Deployment

### Development/Staging

```bash
cd SubscribeCoffieBackend
supabase db reset  # Applies all migrations
```

### Production

```bash
cd SubscribeCoffieBackend
supabase db push  # Applies only new migration
```

## Related Files

- `supabase/migrations/20260120120000_mvp_coffee.sql` - Updated base migration
- `supabase/migrations/20260205000001_fix_wallets_rls_security.sql` - Cleanup migration
- `FIX_007_RLS_POLICY_HARDENING.md` - Original security audit document (if exists)

## Impact Assessment

### Low Risk Changes
- ✅ No existing legitimate code should be updating wallets directly via client
- ✅ All balance updates should go through RPC functions or backend
- ✅ SELECT and INSERT operations unaffected

### High Risk if Not Fixed
- ⚠️ Users could arbitrarily increase balances
- ⚠️ Financial fraud potential
- ⚠️ Audit trail bypass

## Next Steps

1. **Immediate**: Apply cleanup migration to all environments
2. **Short-term**: Audit all wallet balance update logic
3. **Medium-term**: Implement comprehensive top-up RPC with payment integration
4. **Long-term**: Add audit logging for all balance changes

---

**Fixed by**: AI Assistant  
**Date**: 2026-02-05  
**Status**: ✅ COMPLETE - Ready for review and deployment
