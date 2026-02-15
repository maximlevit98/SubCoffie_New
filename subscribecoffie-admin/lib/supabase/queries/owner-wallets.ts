import { createServerClient } from "../server";

// Re-use types from admin wallets
import type {
  AdminWallet,
  AdminWalletOverview,
  AdminWalletTransaction,
  AdminWalletPayment,
  AdminWalletOrder,
} from "./wallets";

// Owner wallets stats type
export type OwnerWalletsStats = {
  total_wallets: number;
  total_balance_credits: number;
  total_topups_credits: number;
  total_payments_credits: number;
  net_change_credits: number;
};

/**
 * Получает кошельки для кофеен владельца через owner RPC
 */
export async function listOwnerWallets(options?: {
  limit?: number;
  offset?: number;
  search?: string;
  cafe_id?: string;
  sort_by?: "balance" | "lifetime" | "last_activity";
  sort_order?: "asc" | "desc";
}) {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallets", {
    p_limit: options?.limit || 50,
    p_offset: options?.offset || 0,
    p_search: options?.search || null,
    p_cafe_id: options?.cafe_id || null,
    p_sort_by: options?.sort_by || "last_activity",
    p_sort_order: options?.sort_order || "desc",
  });

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data as AdminWallet[] | null, error: null };
}

/**
 * Получает статистику по кошелькам владельца через owner RPC
 */
export async function getOwnerWalletsStats() {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallets_stats");

  if (error) {
    return { data: null, error: error.message };
  }

  // RPC returns single row as array, take first element
  const stats = (data?.[0] || {
    total_wallets: 0,
    total_balance_credits: 0,
    total_topups_credits: 0,
    total_payments_credits: 0,
    net_change_credits: 0,
  }) as OwnerWalletsStats;

  return { data: stats, error: null };
}

/**
 * Получает детальный обзор кошелька через owner RPC
 */
export async function getOwnerWalletOverview(walletId: string) {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallet_overview", {
    p_wallet_id: walletId,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  // RPC returns single row as array, take first element
  return { data: (data?.[0] as AdminWalletOverview) || null, error: null };
}

/**
 * Получает транзакции кошелька через owner RPC
 */
export async function getOwnerWalletTransactions(
  walletId: string,
  limit: number = 50,
  offset: number = 0
) {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallet_transactions", {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data as AdminWalletTransaction[] | null, error: null };
}

/**
 * Получает платежи кошелька через owner RPC
 */
export async function getOwnerWalletPayments(
  walletId: string,
  limit: number = 50,
  offset: number = 0
) {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallet_payments", {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data as AdminWalletPayment[] | null, error: null };
}

/**
 * Получает заказы кошелька через owner RPC
 */
export async function getOwnerWalletOrders(
  walletId: string,
  limit: number = 50,
  offset: number = 0
) {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallet_orders", {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data as AdminWalletOrder[] | null, error: null };
}
