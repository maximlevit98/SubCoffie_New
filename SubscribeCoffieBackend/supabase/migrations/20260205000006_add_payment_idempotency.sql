-- Migration: Add Idempotency Support to Payment Transactions
-- Description: Adds idempotency_key to prevent duplicate payment processing
-- Date: 2026-02-05
-- Reference: Stripe idempotency best practices
-- Note: This migration is safe to apply even if real_payment_integration.sql.disabled is not enabled

-- ============================================================================
-- 1. Add idempotency_key column to payment_transactions
-- ============================================================================

alter table public.payment_transactions
  add column if not exists idempotency_key text;

-- Create unique index for idempotency (allows NULL for backward compatibility)
create unique index if not exists payment_transactions_idempotency_key_idx
  on public.payment_transactions(idempotency_key)
  where idempotency_key is not null;

comment on column public.payment_transactions.idempotency_key is 
  'Idempotency key to prevent duplicate payment processing. Format: {userId}_{timestamp}_{uuid}';

-- ============================================================================
-- 2. Add idempotency tracking to webhook events
-- ============================================================================

-- Webhook event_id is already unique and serves as idempotency key
-- Add index for faster lookups (only if table exists)
do $$
begin
  if exists (
    select 1 from information_schema.tables 
    where table_name = 'payment_webhook_events' and table_schema = 'public'
  ) then
    create index if not exists payment_webhook_events_event_id_idx 
      on public.payment_webhook_events(event_id);
  end if;
end
$$;

-- ============================================================================
-- 3. Update mock_wallet_topup to support idempotency
-- ============================================================================

-- Drop existing function to allow signature change
drop function if exists public.mock_wallet_topup(uuid, int, uuid);
drop function if exists public.mock_wallet_topup(uuid, int, uuid, text);

create or replace function public.mock_wallet_topup(
  p_wallet_id uuid,
  p_amount int,
  p_payment_method_id uuid default null,
  p_idempotency_key text default null  -- ✅ NEW: Idempotency support
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id uuid;
  v_wallet_type wallet_type;
  v_commission int;
  v_amount_credited int;
  v_transaction_id uuid;
  v_mock_provider_id text;
  v_existing_transaction record;
begin
  -- ✅ Check idempotency first
  if p_idempotency_key is not null then
    select id, status, amount_credits, commission_credits, metadata
    into v_existing_transaction
    from public.payment_transactions
    where idempotency_key = p_idempotency_key
    limit 1;
    
    if v_existing_transaction.id is not null then
      -- Transaction already exists with this idempotency key
      return jsonb_build_object(
        'success', true,
        'transaction_id', v_existing_transaction.id,
        'amount', v_existing_transaction.amount_credits,
        'commission', v_existing_transaction.commission_credits,
        'amount_credited', v_existing_transaction.amount_credits - v_existing_transaction.commission_credits,
        'status', v_existing_transaction.status,
        'message', 'Idempotent: Transaction already processed',
        'provider', coalesce(v_existing_transaction.metadata->>'provider', 'mock')
      );
    end if;
  end if;

  -- Get wallet info
  select user_id, wallet_type into v_user_id, v_wallet_type
  from public.wallets
  where id = p_wallet_id;

  if v_user_id is null then
    raise exception 'Wallet not found';
  end if;

  -- Calculate commission
  v_commission := public.calculate_commission(p_amount, 'topup', v_wallet_type);
  v_amount_credited := p_amount - v_commission;
  v_mock_provider_id := 'mock_' || gen_random_uuid()::text;

  -- ✅ Insert with idempotency_key
  insert into public.payment_transactions (
    user_id, wallet_id, amount_credits, commission_credits,
    transaction_type, payment_method_id, status, 
    provider_transaction_id, completed_at,
    idempotency_key  -- ✅ Store idempotency key
  )
  values (
    v_user_id, p_wallet_id, p_amount, v_commission,
    'topup', p_payment_method_id, 'completed', 
    v_mock_provider_id, now(),
    p_idempotency_key  -- ✅ Store key
  )
  returning id into v_transaction_id;

  -- Update wallet balance
  update public.wallets
  set
    balance_credits = balance_credits + v_amount_credited,
    lifetime_top_up_credits = lifetime_top_up_credits + v_amount_credited,
    updated_at = now()
  where id = p_wallet_id;

  return jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount,
    'commission', v_commission,
    'amount_credited', v_amount_credited,
    'provider_transaction_id', v_mock_provider_id,
    'provider', 'mock'
  );
end;
$$;

comment on function public.mock_wallet_topup is 
  'Mock wallet top-up with idempotency support. Prevents duplicate processing when same idempotency_key is used.';

-- ============================================================================
-- 4. Create helper function to validate idempotency keys
-- ============================================================================

create or replace function public.validate_idempotency_key(p_key text)
returns boolean
language plpgsql
immutable
as $$
begin
  -- Check format: {userId}_{timestamp}_{uuid}
  -- Example: "a1b2c3d4-e5f6-7890-abcd-ef1234567890_1643723456789_x9y8z7w6-v5u4-3210-fedc-ba0987654321"
  
  if p_key is null then
    return false;
  end if;
  
  if length(p_key) < 50 or length(p_key) > 200 then
    return false;
  end if;
  
  -- Must contain at least 2 underscores
  if (length(p_key) - length(replace(p_key, '_', ''))) < 2 then
    return false;
  end if;
  
  return true;
end;
$$;

comment on function public.validate_idempotency_key is 
  'Validates idempotency key format: {userId}_{timestamp}_{uuid}';

-- ============================================================================
-- 5. Add rate limiting table (for future use)
-- ============================================================================

create table if not exists public.payment_rate_limits (
  user_id uuid not null,
  window_start timestamptz not null default now(),
  attempt_count int default 1,
  last_attempt_at timestamptz default now(),
  created_at timestamptz default now(),
  constraint payment_rate_limits_pk primary key (user_id, window_start)
);

comment on table public.payment_rate_limits is 
  'Tracks payment attempts for rate limiting. Window: 1 hour, Max: 10 attempts.';

-- Enable RLS
alter table public.payment_rate_limits enable row level security;

-- Policies
create policy "Users can view own rate limits"
  on public.payment_rate_limits for select
  using (user_id = auth.uid());

create policy "System can manage rate limits"
  on public.payment_rate_limits for all
  using (true);  -- Will be called by SECURITY DEFINER functions

-- Index for cleanup
create index if not exists payment_rate_limits_window_start_idx
  on public.payment_rate_limits(window_start);

-- ============================================================================
-- 6. Create function to check rate limits
-- ============================================================================

create or replace function public.check_payment_rate_limit(
  p_user_id uuid,
  p_max_attempts int default 10,
  p_window_minutes int default 60
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_window_start timestamptz;
  v_attempt_count int;
  v_is_allowed boolean;
begin
  -- Calculate current window start (truncate to hour)
  v_window_start := date_trunc('hour', now());
  
  -- Get current attempt count for this window
  select attempt_count into v_attempt_count
  from public.payment_rate_limits
  where user_id = p_user_id
    and window_start = v_window_start;
  
  v_attempt_count := coalesce(v_attempt_count, 0);
  v_is_allowed := v_attempt_count < p_max_attempts;
  
  -- If allowed, increment counter
  if v_is_allowed then
    insert into public.payment_rate_limits (user_id, window_start, attempt_count, last_attempt_at)
    values (p_user_id, v_window_start, 1, now())
    on conflict (user_id, window_start) do update
    set
      attempt_count = public.payment_rate_limits.attempt_count + 1,
      last_attempt_at = now();
  end if;
  
  return jsonb_build_object(
    'is_allowed', v_is_allowed,
    'attempts_remaining', greatest(0, p_max_attempts - v_attempt_count - 1),
    'window_resets_at', v_window_start + interval '1 hour'
  );
end;
$$;

comment on function public.check_payment_rate_limit is 
  'Checks if user has exceeded payment rate limit (default: 10 per hour)';

grant execute on function public.check_payment_rate_limit(uuid, int, int) to authenticated;

-- ============================================================================
-- 7. Cleanup old rate limit windows (scheduled job)
-- ============================================================================

-- Note: This should be called by a cron job (e.g., pg_cron or Edge Function)
create or replace function public.cleanup_old_rate_limits()
returns int
language plpgsql
security definer
as $$
declare
  v_deleted_count int;
begin
  -- Delete rate limit windows older than 24 hours
  delete from public.payment_rate_limits
  where window_start < now() - interval '24 hours';
  
  get diagnostics v_deleted_count = row_count;
  
  return v_deleted_count;
end;
$$;

comment on function public.cleanup_old_rate_limits is 
  'Cleanup rate limit records older than 24 hours. Run daily via cron.';

grant execute on function public.cleanup_old_rate_limits() to authenticated;

-- ============================================================================
-- 8. Documentation
-- ============================================================================

comment on table public.payment_transactions is 
  'Payment transactions with idempotency support. Use idempotency_key to prevent duplicate processing.

Example usage:
  SELECT mock_wallet_topup(
    wallet_id,
    1000,
    payment_method_id,
    ''user_123_1643723456789_uuid_here''  -- Idempotency key
  );

Rate limiting:
  - Max 10 payment attempts per hour
  - Check with: SELECT check_payment_rate_limit(user_id);
  
Idempotency key format:
  {userId}_{timestamp}_{uuid}
  
This ensures:
  - Unique per user
  - Sortable by time
  - Globally unique via UUID';
