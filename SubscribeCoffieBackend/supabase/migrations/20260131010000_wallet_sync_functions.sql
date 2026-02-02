-- Migration: Wallet Sync Functions
-- Description: RPC функции для синхронизации кошельков и транзакций

-- ============================================================================
-- 1. Функция получения кошелька пользователя
-- ============================================================================

create or replace function get_user_wallet(user_id_param uuid)
returns jsonb
security definer
language plpgsql
as $$
declare
  result jsonb;
  wallet_record record;
begin
  -- Получаем кошелек
  select * into wallet_record
  from public.wallets
  where user_id = user_id_param
  limit 1;
  
  if not found then
    -- Создаем кошелек если не существует
    insert into public.wallets (user_id, balance, bonus_balance, lifetime_topup)
    values (user_id_param, 0, 0, 0)
    returning * into wallet_record;
  end if;
  
  -- Формируем результат
  select jsonb_build_object(
    'id', wallet_record.id,
    'user_id', wallet_record.user_id,
    'balance', wallet_record.balance,
    'bonus_balance', coalesce(wallet_record.bonus_balance, 0),
    'lifetime_topup', coalesce(wallet_record.lifetime_topup, 0),
    'created_at', wallet_record.created_at,
    'updated_at', wallet_record.updated_at
  ) into result;
  
  return result;
end;
$$;

comment on function get_user_wallet is 'Получает кошелек пользователя, создает если не существует';

-- ============================================================================
-- 2. Функция добавления транзакции
-- ============================================================================

create or replace function add_wallet_transaction(
  user_id_param uuid,
  amount_param int,
  type_param text,
  description_param text default null,
  order_id_param uuid default null,
  actor_user_id_param uuid default null
)
returns jsonb
security definer
language plpgsql
as $$
declare
  wallet_record record;
  transaction_id uuid;
  result jsonb;
begin
  -- Проверяем валидность типа транзакции
  if type_param not in ('topup', 'bonus', 'payment', 'refund', 'admin_credit', 'admin_debit') then
    raise exception 'Invalid transaction type: %', type_param;
  end if;
  
  -- Проверяем amount
  if amount_param <= 0 and type_param not in ('admin_debit') then
    raise exception 'Amount must be positive';
  end if;
  
  -- Получаем или создаем кошелек
  select * into wallet_record
  from public.wallets
  where user_id = user_id_param
  limit 1;
  
  if not found then
    insert into public.wallets (user_id, balance, bonus_balance, lifetime_topup)
    values (user_id_param, 0, 0, 0)
    returning * into wallet_record;
  end if;
  
  -- Создаем транзакцию
  insert into public.wallet_transactions (
    wallet_id,
    amount,
    type,
    description,
    order_id,
    actor_user_id,
    balance_before,
    balance_after
  )
  values (
    wallet_record.id,
    amount_param,
    type_param,
    description_param,
    order_id_param,
    actor_user_id_param,
    wallet_record.balance,
    case 
      when type_param in ('topup', 'bonus', 'refund', 'admin_credit') then wallet_record.balance + amount_param
      when type_param in ('payment', 'admin_debit') then wallet_record.balance - abs(amount_param)
      else wallet_record.balance
    end
  )
  returning id into transaction_id;
  
  -- Обновляем баланс кошелька
  update public.wallets
  set 
    balance = case 
      when type_param in ('topup', 'bonus', 'refund', 'admin_credit') then balance + amount_param
      when type_param in ('payment', 'admin_debit') then balance - abs(amount_param)
      else balance
    end,
    bonus_balance = case
      when type_param = 'bonus' then coalesce(bonus_balance, 0) + amount_param
      else bonus_balance
    end,
    lifetime_topup = case
      when type_param = 'topup' then coalesce(lifetime_topup, 0) + amount_param
      else lifetime_topup
    end,
    updated_at = now()
  where id = wallet_record.id;
  
  -- Получаем обновленный кошелек
  select jsonb_build_object(
    'transaction_id', transaction_id,
    'wallet', (
      select jsonb_build_object(
        'id', id,
        'balance', balance,
        'bonus_balance', bonus_balance,
        'lifetime_topup', lifetime_topup
      )
      from public.wallets
      where id = wallet_record.id
    )
  ) into result;
  
  return result;
end;
$$;

comment on function add_wallet_transaction is 'Добавляет транзакцию и обновляет баланс кошелька';

-- ============================================================================
-- 3. Функция пересчета баланса из транзакций
-- ============================================================================

create or replace function sync_wallet_balance(wallet_id_param uuid)
returns jsonb
security definer
language plpgsql
as $$
declare
  calculated_balance int;
  calculated_bonus int;
  calculated_lifetime int;
  result jsonb;
begin
  -- Рассчитываем баланс из транзакций
  select 
    coalesce(sum(
      case 
        when type in ('topup', 'bonus', 'refund', 'admin_credit') then amount
        when type in ('payment', 'admin_debit') then -abs(amount)
        else 0
      end
    ), 0),
    coalesce(sum(case when type = 'bonus' then amount else 0 end), 0),
    coalesce(sum(case when type = 'topup' then amount else 0 end), 0)
  into calculated_balance, calculated_bonus, calculated_lifetime
  from public.wallet_transactions
  where wallet_id = wallet_id_param;
  
  -- Обновляем кошелек
  update public.wallets
  set 
    balance = calculated_balance,
    bonus_balance = calculated_bonus,
    lifetime_topup = calculated_lifetime,
    updated_at = now()
  where id = wallet_id_param;
  
  -- Возвращаем результат
  select jsonb_build_object(
    'wallet_id', id,
    'old_balance', balance,
    'new_balance', calculated_balance,
    'synced_at', now()
  ) into result
  from public.wallets
  where id = wallet_id_param;
  
  return result;
end;
$$;

comment on function sync_wallet_balance is 'Пересчитывает баланс кошелька из транзакций';

-- ============================================================================
-- 4. Функция получения истории транзакций
-- ============================================================================

create or replace function get_wallet_transactions(
  user_id_param uuid,
  limit_param int default 50,
  offset_param int default 0
)
returns table (
  id uuid,
  wallet_id uuid,
  amount int,
  type text,
  description text,
  order_id uuid,
  balance_before int,
  balance_after int,
  created_at timestamptz
)
security definer
language plpgsql
as $$
begin
  return query
  select 
    wt.id,
    wt.wallet_id,
    wt.amount,
    wt.type,
    wt.description,
    wt.order_id,
    wt.balance_before,
    wt.balance_after,
    wt.created_at
  from public.wallet_transactions wt
  join public.wallets w on w.id = wt.wallet_id
  where w.user_id = user_id_param
  order by wt.created_at desc
  limit limit_param
  offset offset_param;
end;
$$;

comment on function get_wallet_transactions is 'Получает историю транзакций пользователя';

-- ============================================================================
-- 5. Функция получения статистики кошельков
-- ============================================================================

create or replace function get_wallets_stats()
returns jsonb
security definer
language plpgsql
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'total_wallets', count(*),
    'total_balance', coalesce(sum(balance), 0),
    'total_bonus', coalesce(sum(bonus_balance), 0),
    'total_lifetime_topup', coalesce(sum(lifetime_topup), 0),
    'avg_balance', coalesce(avg(balance), 0),
    'transactions_count', (
      select count(*) from public.wallet_transactions
    )
  ) into result
  from public.wallets;
  
  return result;
end;
$$;

comment on function get_wallets_stats is 'Получает статистику по всем кошелькам';

-- ============================================================================
-- Grant permissions
-- ============================================================================

grant execute on function get_user_wallet to authenticated;
grant execute on function add_wallet_transaction to authenticated;
grant execute on function get_wallet_transactions to authenticated;
grant execute on function sync_wallet_balance to authenticated;
grant execute on function get_wallets_stats to authenticated;
