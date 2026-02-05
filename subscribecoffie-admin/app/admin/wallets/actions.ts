"use server";

import { revalidatePath } from "next/cache";

import { createAdminClient } from "../../../lib/supabase/admin";
import { requireAdmin } from "../../../lib/supabase/roles";

/**
 * DEPRECATED: add_wallet_transaction RPC removed in canonical schema migration
 * TODO: Implement direct transaction insertion or new canonical RPC
 */
export async function addManualTransaction(
  userId: string,
  amount: number,
  type: "credit" | "debit",
  reason: string
) {
  const { userId: adminId } = await requireAdmin();
  
  // TEMPORARILY DISABLED - RPC deprecated
  throw new Error(
    "add_wallet_transaction RPC deprecated. Use new canonical wallet system. " +
    "Migration: 20260205000003_unify_wallets_schema.sql"
  );
  
  // TODO: Implement with canonical schema:
  // 1. Get user's wallet(s) via get_user_wallets(p_user_id)
  // 2. Insert into wallet_transactions with all canonical fields
  // 3. Update wallet balance_credits directly
  // 4. Revalidate paths
}

/**
 * DEPRECATED: sync_wallet_balance RPC removed in canonical schema migration
 * Balance is now authoritative from balance_credits column, not calculated
 */
export async function syncWalletBalance(walletId: string) {
  await requireAdmin();
  
  throw new Error(
    "sync_wallet_balance RPC deprecated. " +
    "Canonical schema uses balance_credits as source of truth."
  );
}

/**
 * Получает все кошельки пользователя (UPDATED: P4 - returns array)
 */
export async function getUserWallets(userId: string) {
  await requireAdmin();
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_user_wallets", {
    p_user_id: userId,
  });

  if (error) {
    throw new Error(`Failed to get wallets: ${error.message}`);
  }

  return data || [];
}

/**
 * Получает транзакции кошелька (UPDATED: direct query)
 */
export async function getUserTransactions(
  walletId: string,
  limit: number = 50,
  offset: number = 0
) {
  await requireAdmin();
  const supabase = createAdminClient();

  const { data, error } = await supabase
    .from("wallet_transactions")
    .select("*")
    .eq("wallet_id", walletId)
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) {
    throw new Error(`Failed to get transactions: ${error.message}`);
  }

  return data || [];
}
