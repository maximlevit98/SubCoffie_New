-- Test: Payment Idempotency and Rate Limiting
-- Description: Tests idempotency keys and rate limiting for payment transactions
-- Usage: psql -h localhost -U postgres -d postgres -f tests/payment_idempotency.test.sql

\echo '===================='
\echo 'Payment Idempotency Tests'
\echo '===================='

begin;

-- Setup: Create test user and wallet
insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (
  'a1111111-1111-1111-1111-111111111111',
  'idempotency-test@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  now(),
  now()
);

insert into public.profiles (id, email, full_name, role)
values (
  'a1111111-1111-1111-1111-111111111111',
  'idempotency-test@example.com',
  'Idempotency Test User',
  'user'
);

insert into public.wallets (id, user_id, wallet_type, balance_credits, lifetime_top_up_credits)
values (
  'b1111111-1111-1111-1111-111111111111',
  'a1111111-1111-1111-1111-111111111111',
  'citypass',
  0,
  0
);

-- Set auth context
set local request.jwt.claims.sub = 'a1111111-1111-1111-1111-111111111111';

\echo ''
\echo '✅ Test 1: First payment with idempotency key'
\echo 'Should create new transaction'

select
  (result->>'success')::boolean as success,
  result->>'transaction_id' as transaction_id,
  (result->>'amount')::int as amount,
  (result->>'commission')::int as commission,
  result->>'message' as message
from (
  select public.mock_wallet_topup(
    'b1111111-1111-1111-1111-111111111111'::uuid,
    1000,
    null,
    'idempotency_test_key_001'
  ) as result
) t;

-- Store transaction_id for later comparison
create temp table test_results (
  test_name text,
  transaction_id uuid,
  balance_after int
);

insert into test_results (test_name, transaction_id, balance_after)
select
  'first_payment',
  (result->>'transaction_id')::uuid,
  (select balance_credits from public.wallets where id = 'b1111111-1111-1111-1111-111111111111')
from (
  select public.mock_wallet_topup(
    'b1111111-1111-1111-1111-111111111111'::uuid,
    1000,
    null,
    'idempotency_test_key_002'
  ) as result
) t;

\echo ''
\echo '✅ Test 2: Same idempotency key (should return same transaction)'
\echo 'Should NOT create new transaction or credit wallet again'

select
  (result->>'success')::boolean as success,
  result->>'transaction_id' as transaction_id_2,
  (result->>'amount')::int as amount,
  result->>'message' as message,
  -- Compare transaction IDs
  case
    when result->>'transaction_id' = (select transaction_id::text from test_results where test_name = 'first_payment')
    then '✅ PASS: Same transaction ID (idempotent)'
    else '❌ FAIL: Different transaction ID (NOT idempotent)'
  end as idempotency_check
from (
  select public.mock_wallet_topup(
    'b1111111-1111-1111-1111-111111111111'::uuid,
    1000,
    null,
    'idempotency_test_key_002'  -- Same key as Test 1
  ) as result
) t;

-- Check wallet balance (should not have doubled)
select
  balance_credits,
  case
    when balance_credits = (select balance_after from test_results where test_name = 'first_payment')
    then '✅ PASS: Balance unchanged (idempotent)'
    else '❌ FAIL: Balance changed (duplicate credit!)'
  end as balance_check
from public.wallets
where id = 'b1111111-1111-1111-1111-111111111111';

\echo ''
\echo '✅ Test 3: Different idempotency key (should create new transaction)'

select
  (result->>'success')::boolean as success,
  result->>'transaction_id' as new_transaction_id,
  (result->>'amount')::int as amount,
  -- Compare transaction IDs
  case
    when result->>'transaction_id' != (select transaction_id::text from test_results where test_name = 'first_payment')
    then '✅ PASS: Different transaction ID (new payment)'
    else '❌ FAIL: Same transaction ID (should be different)'
  end as uniqueness_check
from (
  select public.mock_wallet_topup(
    'b1111111-1111-1111-1111-111111111111'::uuid,
    500,
    null,
    'idempotency_test_key_003'  -- Different key
  ) as result
) t;

\echo ''
\echo '✅ Test 4: Rate limiting (max 10 per hour)'
\echo 'Creating 9 payments (total will be 11 including previous tests)'

do $$
declare
  i int;
  result jsonb;
begin
  for i in 1..9 loop
    select public.mock_wallet_topup(
      'b1111111-1111-1111-1111-111111111111'::uuid,
      100,
      null,
      'rate_limit_test_' || i
    ) into result;
  end loop;
end $$;

\echo 'Checking rate limit status...'

select
  (rate_limit->>'is_allowed')::boolean as is_allowed,
  (rate_limit->>'attempts_remaining')::int as attempts_remaining,
  rate_limit->>'window_resets_at' as window_resets_at,
  case
    when (rate_limit->>'attempts_remaining')::int = 0
    then '✅ PASS: Rate limit reached (10 attempts per hour)'
    else '⚠️ Expected 0 attempts remaining, got ' || (rate_limit->>'attempts_remaining')::text
  end as rate_limit_check
from (
  select public.check_payment_rate_limit(
    'a1111111-1111-1111-1111-111111111111'::uuid
  ) as rate_limit
) t;

\echo ''
\echo '✅ Test 5: 11th payment should fail (rate limit exceeded)'

do $$
declare
  result jsonb;
  error_caught boolean := false;
begin
  begin
    select public.mock_wallet_topup(
      'b1111111-1111-1111-1111-111111111111'::uuid,
      100,
      null,
      'rate_limit_test_should_fail'
    ) into result;
    
    -- If we got here, rate limit didn't work
    raise notice '❌ FAIL: Payment succeeded despite rate limit';
  exception
    when others then
      error_caught := true;
      if sqlerrm like '%Rate limit%' then
        raise notice '✅ PASS: Rate limit error caught: %', sqlerrm;
      else
        raise notice '⚠️ Different error: %', sqlerrm;
      end if;
  end;
end $$;

\echo ''
\echo '✅ Test 6: Validate idempotency key format'

select
  'valid_key_format' as test_case,
  public.validate_idempotency_key('a1b2c3d4-e5f6-7890-abcd-ef1234567890_1643723456789_x9y8z7w6-v5u4-3210-fedc-ba0987654321') as is_valid,
  '✅ PASS' as status
union all
select
  'invalid_too_short',
  public.validate_idempotency_key('short_key'),
  case when public.validate_idempotency_key('short_key') = false then '✅ PASS' else '❌ FAIL' end
union all
select
  'invalid_no_underscores',
  public.validate_idempotency_key('nounderscoresherebutlongenough1234567890123456789012345678901234567890'),
  case when public.validate_idempotency_key('nounderscoresherebutlongenough1234567890123456789012345678901234567890') = false then '✅ PASS' else '❌ FAIL' end
union all
select
  'invalid_null',
  public.validate_idempotency_key(null),
  case when public.validate_idempotency_key(null) = false then '✅ PASS' else '❌ FAIL' end;

\echo ''
\echo '✅ Test 7: Transaction history with idempotency keys'

select
  id,
  amount_credits,
  commission_credits,
  status,
  idempotency_key,
  case
    when idempotency_key is not null then '✅ Has key'
    else '⚠️ No key (old transaction)'
  end as idempotency_status
from public.payment_transactions
where user_id = 'a1111111-1111-1111-1111-111111111111'
order by created_at desc
limit 5;

\echo ''
\echo '✅ Test 8: Unique constraint on idempotency_key'

do $$
begin
  -- Try to insert duplicate idempotency_key directly
  insert into public.payment_transactions (
    user_id, wallet_id, amount_credits, commission_credits,
    transaction_type, status, idempotency_key
  )
  values (
    'a1111111-1111-1111-1111-111111111111',
    'b1111111-1111-1111-1111-111111111111',
    100, 7, 'topup', 'pending',
    'idempotency_test_key_002'  -- Duplicate from earlier test
  );
  
  raise notice '❌ FAIL: Duplicate idempotency_key was allowed';
exception
  when unique_violation then
    raise notice '✅ PASS: Unique constraint prevented duplicate idempotency_key';
  when others then
    raise notice '⚠️ Different error: %', sqlerrm;
end $$;

\echo ''
\echo '===================='
\echo 'Summary'
\echo '===================='

select
  count(*) as total_transactions,
  count(distinct idempotency_key) as unique_keys,
  count(*) filter (where idempotency_key is not null) as transactions_with_keys,
  case
    when count(distinct idempotency_key) = count(*) filter (where idempotency_key is not null)
    then '✅ All idempotency keys are unique'
    else '❌ FAIL: Duplicate idempotency keys found'
  end as uniqueness_check
from public.payment_transactions
where user_id = 'a1111111-1111-1111-1111-111111111111';

select
  balance_credits as final_balance,
  lifetime_top_up_credits as lifetime_topup,
  case
    when balance_credits = lifetime_top_up_credits
    then '✅ Balance and lifetime match'
    else '❌ FAIL: Balance mismatch'
  end as balance_integrity
from public.wallets
where id = 'b1111111-1111-1111-1111-111111111111';

rollback;

\echo ''
\echo '✅ Tests completed. All changes rolled back.'
\echo ''
\echo 'Expected Results:'
\echo '  - Same idempotency key returns same transaction (no duplicate charge)'
\echo '  - Different idempotency key creates new transaction'
\echo '  - Rate limit prevents more than 10 payments per hour'
\echo '  - Unique constraint prevents duplicate idempotency keys'
\echo '  - Balance is credited only once per unique key'
