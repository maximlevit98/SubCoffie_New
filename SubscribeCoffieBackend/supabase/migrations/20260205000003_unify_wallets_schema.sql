-- Migration: Unify Wallets Schema to Canonical Format
-- Priority: P0 (Critical Schema Unification)
-- Date: 2026-02-05
-- 
-- CANONICAL FORMAT (from 20260201000002_wallet_types_mock_payments.sql):
--   - wallet_type (enum: 'citypass' | 'cafe_wallet')
--   - balance_credits (int, NOT NULL)
--   - lifetime_top_up_credits (int, NOT NULL, default 0)
--
-- PROBLEMS:
--   1. mvp_coffee.sql uses: type, credits_balance, bonus_balance
--   2. wallet_sync_functions.sql uses: balance, bonus_balance, lifetime_topup
--   3. Inconsistent naming across migrations
--
-- SOLUTION: Migrate all to canonical format

-- ============================================================================
-- STEP 1: Backup old column names (for rollback if needed)
-- ============================================================================

-- Columns that will be migrated:
--   type → wallet_type
--   credits_balance / balance → balance_credits
--   bonus_balance → (remove, merge into balance_credits)
--   lifetime_topup → lifetime_top_up_credits

-- ============================================================================
-- STEP 2: Add new canonical columns
-- ============================================================================

-- Add wallet_type enum if not exists
do $$
begin
  if not exists (select 1 from pg_type where typname = 'wallet_type') then
    create type wallet_type as enum ('citypass', 'cafe_wallet');
  end if;
end
$$;

-- Add canonical columns
alter table public.wallets
  add column if not exists wallet_type wallet_type,
  add column if not exists balance_credits int,
  add column if not exists lifetime_top_up_credits int default 0;

-- ============================================================================
-- STEP 3: Migrate data from old columns to new
-- ============================================================================

-- Migrate wallet_type from 'type' column
update public.wallets
set wallet_type = case
  when type = 'citypass' then 'citypass'::wallet_type
  when type = 'cafe' then 'cafe_wallet'::wallet_type
  when type = 'cafe_wallet' then 'cafe_wallet'::wallet_type
  else 'citypass'::wallet_type  -- default fallback
end
where wallet_type is null;

-- Migrate balance_credits (handle both 'balance' and 'credits_balance')
do $$
begin
  -- Check if 'balance' column exists
  if exists (
    select 1 from information_schema.columns 
    where table_name = 'wallets' and column_name = 'balance'
  ) then
    update public.wallets
    set balance_credits = coalesce(
      balance_credits,  -- if already set (from newer migrations)
      balance,          -- from wallet_sync_functions.sql
      credits_balance,  -- from mvp_coffee.sql
      0                 -- fallback
    )
    where balance_credits is null or balance_credits = 0;
  elsif exists (
    select 1 from information_schema.columns 
    where table_name = 'wallets' and column_name = 'credits_balance'
  ) then
    update public.wallets
    set balance_credits = coalesce(
      balance_credits,  -- if already set
      credits_balance,  -- from mvp_coffee.sql
      0                 -- fallback
    )
    where balance_credits is null or balance_credits = 0;
  else
    -- Both columns don't exist, balance_credits is already canonical
    update public.wallets
    set balance_credits = coalesce(balance_credits, 0)
    where balance_credits is null;
  end if;
end
$$;

-- Merge bonus_balance into balance_credits if bonus_balance exists
do $$
begin
  if exists (
    select 1 from information_schema.columns 
    where table_name = 'wallets' and column_name = 'bonus_balance'
  ) then
    update public.wallets
    set balance_credits = balance_credits + coalesce(bonus_balance, 0)
    where bonus_balance > 0;
  end if;
end
$$;

-- Migrate lifetime_top_up_credits from lifetime_topup
do $$
begin
  if exists (
    select 1 from information_schema.columns 
    where table_name = 'wallets' and column_name = 'lifetime_topup'
  ) then
    update public.wallets
    set lifetime_top_up_credits = coalesce(lifetime_topup, 0)
    where lifetime_top_up_credits is null or lifetime_top_up_credits = 0;
  end if;
end
$$;

-- ============================================================================
-- STEP 4: Set NOT NULL constraints on canonical columns
-- ============================================================================

-- Set defaults before NOT NULL
update public.wallets
set balance_credits = 0
where balance_credits is null;

update public.wallets
set lifetime_top_up_credits = 0
where lifetime_top_up_credits is null;

update public.wallets
set wallet_type = 'citypass'
where wallet_type is null;

-- Apply NOT NULL constraints
alter table public.wallets
  alter column wallet_type set not null,
  alter column balance_credits set not null,
  alter column lifetime_top_up_credits set not null;

-- ============================================================================
-- STEP 5: Drop old deprecated columns
-- ============================================================================

alter table public.wallets
  drop column if exists type,
  drop column if exists balance,
  drop column if exists credits_balance,
  drop column if exists bonus_balance,
  drop column if exists lifetime_topup;

-- ============================================================================
-- STEP 6: Update constraints
-- ============================================================================

-- Drop old constraint if exists
alter table public.wallets
  drop constraint if exists wallets_type_check;

-- Cafe wallet constraint already exists in wallet_types_mock_payments.sql
-- Ensure it's present
alter table public.wallets
  drop constraint if exists wallets_cafe_wallet_check;

alter table public.wallets
  add constraint wallets_cafe_wallet_check check (
    (wallet_type = 'citypass') or
    (wallet_type = 'cafe_wallet' and (cafe_id is not null or network_id is not null))
  );

-- ============================================================================
-- STEP 7: Update indexes
-- ============================================================================

-- Remove old indexes if they exist
drop index if exists public.wallets_type_idx;

-- Canonical index (already created in wallet_types_mock_payments.sql)
create index if not exists wallets_wallet_type_idx on public.wallets(wallet_type);

-- ============================================================================
-- STEP 8: Update comments
-- ============================================================================

comment on column public.wallets.wallet_type is 
  'CANONICAL: Type of wallet - citypass (universal) or cafe_wallet (tied to cafe/network)';

comment on column public.wallets.balance_credits is 
  'CANONICAL: Current balance in credits (1 credit = 1 RUB). Includes all funds (regular + bonus).';

comment on column public.wallets.lifetime_top_up_credits is 
  'CANONICAL: Total amount topped up over lifetime (for loyalty/analytics)';

comment on table public.wallets is 
  'User wallets with CANONICAL schema: wallet_type, balance_credits, lifetime_top_up_credits. Updated: 2026-02-05';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Count rows to ensure no data loss
do $$
declare
  v_wallet_count int;
  v_zero_balance_count int;
  v_negative_balance_count int;
begin
  select count(*) into v_wallet_count from public.wallets;
  select count(*) into v_zero_balance_count from public.wallets where balance_credits = 0;
  select count(*) into v_negative_balance_count from public.wallets where balance_credits < 0;
  
  raise notice '✅ Migration complete:';
  raise notice '   Total wallets: %', v_wallet_count;
  raise notice '   Zero balance: %', v_zero_balance_count;
  raise notice '   Negative balance (WARNING): %', v_negative_balance_count;
  
  if v_negative_balance_count > 0 then
    raise warning 'Found % wallets with negative balance - review required!', v_negative_balance_count;
  end if;
end
$$;
