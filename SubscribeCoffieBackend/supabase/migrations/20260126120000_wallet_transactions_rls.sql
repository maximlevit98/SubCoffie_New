-- Tighten wallet_transactions access: admin/service only
alter table public.wallet_transactions enable row level security;

-- Ensure any legacy anon policy is removed (if it exists)
drop policy if exists wallet_transactions_anon_all on public.wallet_transactions;
drop policy if exists "wallet_transactions_anon_all" on public.wallet_transactions;

-- Allow only admin users (service role bypasses RLS)
drop policy if exists wallet_transactions_admin_all on public.wallet_transactions;
create policy wallet_transactions_admin_all
  on public.wallet_transactions
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());
