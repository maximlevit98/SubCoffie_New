-- DEPRECATED: This file contains functions using old schema (balance, bonus_balance, lifetime_topup)
-- 
-- These functions are DEPRECATED as of 2026-02-05 migration to canonical schema.
-- Canonical schema uses: wallet_type, balance_credits, lifetime_top_up_credits
--
-- STATUS: These functions will fail after running migration 20260205000003_unify_wallets_schema.sql
-- 
-- RECOMMENDED ACTIONS:
--   1. Use new functions from 20260201000002_wallet_types_mock_payments.sql:
--      - create_citypass_wallet(p_user_id)
--      - create_cafe_wallet(p_user_id, p_cafe_id, p_network_id)
--      - get_user_wallets(p_user_id)
--      - validate_wallet_for_order(p_wallet_id, p_cafe_id)
--      - calculate_commission(p_amount, p_operation_type, p_wallet_type)
--
--   2. For transactions, use wallet_transactions table directly or create new RPC
--
--   3. Remove references to these functions from:
--      - Admin panel (subscribecoffie-admin)
--      - iOS app (SubscribeCoffieClean)
--      - Tests

-- ============================================================================
-- DROP DEPRECATED FUNCTIONS
-- ============================================================================

drop function if exists public.get_user_wallet(uuid);
drop function if exists public.add_wallet_transaction(uuid, int, text, text, uuid, uuid);
drop function if exists public.sync_wallet_balance(uuid);
drop function if exists public.get_wallet_transactions(uuid, int, int);
drop function if exists public.get_wallets_stats();

-- ============================================================================
-- REPLACEMENT GUIDE
-- ============================================================================

comment on schema public is '
DEPRECATED wallet_sync_functions.sql (2026-02-05):

OLD SCHEMA:
  - balance (int)
  - bonus_balance (int)
  - lifetime_topup (int)

NEW CANONICAL SCHEMA (use this):
  - wallet_type (enum: citypass | cafe_wallet)
  - balance_credits (int, NOT NULL)
  - lifetime_top_up_credits (int, NOT NULL, default 0)

REPLACEMENT FUNCTIONS:
  get_user_wallet()        → get_user_wallets()
  add_wallet_transaction() → Use wallet_transactions table directly + RPC for top-up
  sync_wallet_balance()    → Not needed (transactions are authoritative source)
  get_wallet_transactions()→ Query wallet_transactions directly
  get_wallets_stats()      → Create new function if needed

NEW RPC FUNCTIONS (from wallet_types_mock_payments.sql):
  - create_citypass_wallet(p_user_id)
  - create_cafe_wallet(p_user_id, p_cafe_id, p_network_id)
  - get_user_wallets(p_user_id) [already returns canonical format]
  - validate_wallet_for_order(p_wallet_id, p_cafe_id)
  - calculate_commission(p_amount, p_operation_type, p_wallet_type)

MIGRATION PATH:
  1. Update iOS app to use get_user_wallets() instead of get_user_wallet()
  2. Update admin panel wallet queries to use canonical schema
  3. Remove calls to deprecated functions
  4. Apply migration 20260205000003_unify_wallets_schema.sql
';
