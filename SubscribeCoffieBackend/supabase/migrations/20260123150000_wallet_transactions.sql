-- Wallet transactions ledger with full audit trail
-- Updated: 2026-02-05 to match wallet_sync_functions.sql structure
create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  amount int not null,
  type text not null,
  description text,
  order_id uuid,  -- ✅ Removed FK constraint, orders_core created later
  actor_user_id uuid references auth.users(id) on delete set null,
  balance_before int not null,
  balance_after int not null,
  created_at timestamptz not null default now(),
  constraint wallet_transactions_type_check check (type in ('topup', 'bonus', 'payment', 'refund', 'admin_credit', 'admin_debit'))
);

create index if not exists wallet_transactions_wallet_id_idx on public.wallet_transactions (wallet_id);
create index if not exists wallet_transactions_created_at_idx on public.wallet_transactions (created_at desc);
create index if not exists wallet_transactions_type_idx on public.wallet_transactions (type);
create index if not exists wallet_transactions_order_id_idx on public.wallet_transactions (order_id) where order_id is not null;
create index if not exists wallet_transactions_actor_user_id_idx on public.wallet_transactions (actor_user_id) where actor_user_id is not null;

comment on table public.wallet_transactions is 
  'Wallet transactions ledger with full audit trail. Each transaction records balance_before/balance_after for complete audit history.';