-- Migration: Expand wallet_transactions table structure
-- Приводим структуру таблицы в соответствие с RPC функциями из 20260131010000_wallet_sync_functions.sql
-- Date: 2026-02-05

-- Добавляем недостающие колонки
alter table public.wallet_transactions 
  add column if not exists type text,
  add column if not exists description text,
  add column if not exists order_id uuid references public.orders(id) on delete set null,
  add column if not exists actor_user_id uuid references auth.users(id) on delete set null,
  add column if not exists balance_before int,
  add column if not exists balance_after int;

-- Мигрируем данные из старых колонок в новые (если есть данные)
update public.wallet_transactions
set 
  type = case 
    when direction = 'credit' then 'topup'
    when direction = 'debit' then 'payment'
    else 'topup' -- default fallback
  end,
  description = reason
where type is null;

-- Удаляем старые колонки (после миграции данных)
alter table public.wallet_transactions
  drop column if exists direction,
  drop column if exists reason;

-- Добавляем NOT NULL constraints после миграции
alter table public.wallet_transactions
  alter column type set not null,
  alter column balance_before set not null,
  alter column balance_after set not null;

-- Добавляем check constraint для типов
alter table public.wallet_transactions
  drop constraint if exists wallet_transactions_type_check;

alter table public.wallet_transactions
  add constraint wallet_transactions_type_check 
  check (type in ('topup', 'bonus', 'payment', 'refund', 'admin_credit', 'admin_debit'));

-- Создаем индексы для новых колонок
create index if not exists wallet_transactions_type_idx on public.wallet_transactions (type);
create index if not exists wallet_transactions_order_id_idx on public.wallet_transactions (order_id) where order_id is not null;
create index if not exists wallet_transactions_actor_user_id_idx on public.wallet_transactions (actor_user_id) where actor_user_id is not null;

-- Обновляем комментарий к таблице
comment on table public.wallet_transactions is 
  'Wallet transactions ledger with full audit trail. Each transaction records balance_before/balance_after for complete audit history.';

comment on column public.wallet_transactions.type is 
  'Transaction type: topup, bonus, payment, refund, admin_credit, admin_debit';

comment on column public.wallet_transactions.balance_before is 
  'Wallet balance before this transaction (for audit trail)';

comment on column public.wallet_transactions.balance_after is 
  'Wallet balance after this transaction (for audit trail)';

comment on column public.wallet_transactions.order_id is 
  'Related order ID (for payment/refund transactions)';

comment on column public.wallet_transactions.actor_user_id is 
  'User who performed the action (for admin operations)';
