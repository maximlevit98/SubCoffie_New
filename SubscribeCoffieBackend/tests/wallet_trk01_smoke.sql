-- ============================================================================
-- TRK-01 Wallet Smoke Tests (idempotency + normalized errors)
-- ============================================================================

\echo ''
\echo '============================================'
\echo '🧪 TRK-01 Wallet Smoke Tests'
\echo '============================================'

DO $$
DECLARE
  v_user_id uuid;
  v_city_wallet_1 uuid;
  v_city_wallet_2 uuid;
  v_city_count int;
  v_cafe_id uuid;
  v_cafe_wallet_1 uuid;
  v_cafe_wallet_2 uuid;
  v_balance_before int;
  v_balance_after int;
  v_topup_1 jsonb;
  v_topup_2 jsonb;
  v_key text;
BEGIN
  SELECT id INTO v_user_id
  FROM auth.users
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found in auth.users';
  END IF;

  -- 1) New/existing user flow for CityPass wallet
  DELETE FROM public.wallets
  WHERE user_id = v_user_id
    AND wallet_type = 'citypass';

  v_city_wallet_1 := public.create_citypass_wallet(v_user_id);
  v_city_wallet_2 := public.create_citypass_wallet(v_user_id);

  IF v_city_wallet_1 IS NULL OR v_city_wallet_2 IS NULL THEN
    RAISE EXCEPTION 'create_citypass_wallet returned NULL';
  END IF;

  IF v_city_wallet_1 <> v_city_wallet_2 THEN
    RAISE EXCEPTION 'CityPass idempotency failed: % <> %', v_city_wallet_1, v_city_wallet_2;
  END IF;

  SELECT COUNT(*) INTO v_city_count
  FROM public.wallets
  WHERE user_id = v_user_id
    AND wallet_type = 'citypass';

  IF v_city_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly 1 CityPass wallet, got %', v_city_count;
  END IF;

  RAISE NOTICE '✅ CityPass creation idempotency ok';

  -- 2) Cafe wallet idempotency (if cafe exists)
  SELECT id INTO v_cafe_id
  FROM public.cafes
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_cafe_id IS NOT NULL THEN
    DELETE FROM public.wallets
    WHERE user_id = v_user_id
      AND wallet_type = 'cafe_wallet'
      AND cafe_id = v_cafe_id;

    v_cafe_wallet_1 := public.create_cafe_wallet(v_user_id, v_cafe_id, NULL);
    v_cafe_wallet_2 := public.create_cafe_wallet(v_user_id, v_cafe_id, NULL);

    IF v_cafe_wallet_1 <> v_cafe_wallet_2 THEN
      RAISE EXCEPTION 'Cafe wallet idempotency failed: % <> %', v_cafe_wallet_1, v_cafe_wallet_2;
    END IF;

    RAISE NOTICE '✅ Cafe wallet creation idempotency ok';
  ELSE
    RAISE NOTICE '⚠️ SKIP: no cafes found for cafe_wallet test';
  END IF;

  -- 3) Top-up idempotency
  SELECT balance_credits INTO v_balance_before
  FROM public.wallets
  WHERE id = v_city_wallet_1;

  v_key := 'trk01_' || gen_random_uuid()::text;

  v_topup_1 := public.mock_wallet_topup(v_city_wallet_1, 500, NULL, v_key);
  v_topup_2 := public.mock_wallet_topup(v_city_wallet_1, 500, NULL, v_key);

  IF (v_topup_1->>'transaction_id') IS DISTINCT FROM (v_topup_2->>'transaction_id') THEN
    RAISE EXCEPTION 'Top-up idempotency failed: tx ids differ';
  END IF;

  SELECT balance_credits INTO v_balance_after
  FROM public.wallets
  WHERE id = v_city_wallet_1;

  IF v_balance_after <> v_balance_before + (v_topup_1->>'amount_credited')::int THEN
    RAISE EXCEPTION 'Top-up idempotency balance mismatch';
  END IF;

  RAISE NOTICE '✅ Top-up idempotency ok';
END $$;

-- 4) Normalized error: wallet_not_found
DO $$
BEGIN
  PERFORM public.mock_wallet_topup('00000000-0000-0000-0000-000000000001'::uuid, 100, NULL, NULL);
  RAISE EXCEPTION 'Expected wallet_not_found error';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM <> 'wallet_not_found' THEN
      RAISE EXCEPTION 'Expected wallet_not_found, got: %', SQLERRM;
    END IF;
    RAISE NOTICE '✅ Normalized error wallet_not_found ok';
END $$;

\echo '✅ TRK-01 wallet smoke tests finished'
