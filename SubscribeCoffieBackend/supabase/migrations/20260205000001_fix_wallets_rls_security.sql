-- Security fix: Remove direct wallet balance UPDATE permission from users
-- Users can only SELECT their wallets. Balance updates must be done via secure RPC functions.
-- Migration created: 2026-02-05
-- Priority: P0 (Security)

-- Drop the insecure UPDATE policy if it exists
drop policy if exists "Own wallets update" on public.wallets;

-- Verify RLS is enabled
alter table public.wallets enable row level security;

-- Ensure users can still SELECT and INSERT (wallet creation)
do $$
begin
  -- Recreate SELECT policy if missing
  if not exists (
    select 1 from pg_policies 
    where schemaname='public' 
    and tablename='wallets' 
    and policyname='Own wallets select'
  ) then
    create policy "Own wallets select" on public.wallets
      for select using (auth.uid() = user_id);
  end if;

  -- Recreate INSERT policy if missing
  if not exists (
    select 1 from pg_policies 
    where schemaname='public' 
    and tablename='wallets' 
    and policyname='Own wallets insert'
  ) then
    create policy "Own wallets insert" on public.wallets
      for insert with check (auth.uid() = user_id);
  end if;
end$$;

-- Add comment explaining the security model
comment on table public.wallets is 
  'User wallet balances. RLS: Users can SELECT and INSERT their own wallets, but cannot UPDATE balance directly. Balance updates happen via secure RPC functions (top_up, process_order) or backend triggers only.';
