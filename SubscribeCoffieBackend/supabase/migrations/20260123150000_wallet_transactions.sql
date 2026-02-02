-- Wallet transactions ledger (additive, no changes to existing wallet logic)
create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  direction text not null, -- credit/debit
  amount int not null,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists wallet_transactions_wallet_id_idx on public.wallet_transactions (wallet_id);
create index if not exists wallet_transactions_created_at_idx on public.wallet_transactions (created_at desc);
