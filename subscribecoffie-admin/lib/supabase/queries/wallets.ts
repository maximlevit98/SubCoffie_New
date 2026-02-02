import { createAdminClient } from "../admin";

export type Wallet = {
  id: string;
  user_id: string;
  balance: number;
  bonus_balance: number;
  lifetime_topup: number;
  created_at: string;
  updated_at: string;
};

export type WalletTransaction = {
  id: string;
  wallet_id: string;
  amount: number;
  type: string;
  description: string | null;
  order_id: string | null;
  balance_before: number;
  balance_after: number;
  created_at: string;
};

/**
 * Получает все кошельки с информацией о пользователях
 */
export async function listWallets() {
  const supabase = createAdminClient();

  const { data, error } = await supabase
    .from("wallets")
    .select(
      `
      *,
      profiles:user_id (
        id,
        full_name,
        phone
      )
    `
    )
    .order("created_at", { ascending: false });

  return {
    data: data as (Wallet & { profiles: any })[] | null,
    error: error?.message,
  };
}

/**
 * Получает кошелек по ID пользователя
 */
export async function getWalletByUserId(userId: string) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_user_wallet", {
    user_id_param: userId,
  });

  return { data, error: error?.message };
}

/**
 * Получает транзакции кошелька
 */
export async function getWalletTransactions(
  userId: string,
  limit: number = 50,
  offset: number = 0
) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_wallet_transactions", {
    user_id_param: userId,
    limit_param: limit,
    offset_param: offset,
  });

  return { data: data as WalletTransaction[] | null, error: error?.message };
}

/**
 * Получает статистику по кошелькам
 */
export async function getWalletsStats() {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_wallets_stats");

  return { data, error: error?.message };
}
