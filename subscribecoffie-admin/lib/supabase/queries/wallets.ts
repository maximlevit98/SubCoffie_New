import { createAdminClient } from "../admin";

// CANONICAL SCHEMA (updated 2026-02-05 P4 - Multiple wallets support)
export type Wallet = {
  id: string;
  wallet_type: "citypass" | "cafe_wallet";
  balance_credits: number;
  lifetime_top_up_credits: number;
  cafe_id: string | null;
  cafe_name: string | null;
  network_id: string | null;
  network_name: string | null;
  created_at: string;
};

// Extended wallet with user info for list view
export type WalletWithUser = Wallet & {
  user_id: string;
  profiles?: {
    id: string;
    full_name: string | null;
    phone: string | null;
  } | null;
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
 * UPDATED: 2026-02-05 P4 - Returns multiple wallets per user
 */
export async function listWallets() {
  const supabase = createAdminClient();

  const { data, error } = await supabase
    .from("wallets")
    .select(
      `
      id,
      user_id,
      wallet_type,
      balance_credits,
      lifetime_top_up_credits,
      cafe_id,
      network_id,
      created_at,
      profiles:user_id (
        id,
        full_name,
        phone
      ),
      cafes:cafe_id (
        name
      ),
      wallet_networks:network_id (
        name
      )
    `
    )
    .order("created_at", { ascending: false });

  if (error || !data) {
    return { data: null, error: error?.message };
  }

  // Transform to WalletWithUser format
  const wallets: WalletWithUser[] = data.map((w: any) => ({
    id: w.id,
    user_id: w.user_id,
    wallet_type: w.wallet_type,
    balance_credits: w.balance_credits,
    lifetime_top_up_credits: w.lifetime_top_up_credits,
    cafe_id: w.cafe_id,
    cafe_name: w.cafes?.name || null,
    network_id: w.network_id,
    network_name: w.wallet_networks?.name || null,
    created_at: w.created_at,
    profiles: w.profiles,
  }));

  return { data: wallets, error: null };
}

/**
 * Получает все кошельки пользователя по user_id
 * UPDATED: 2026-02-05 P4 - Returns array of wallets (CityPass + Cafe Wallets)
 */
export async function getWalletsByUserId(userId: string): Promise<{ data: Wallet[] | null; error: string | null }> {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_user_wallets", {
    p_user_id: userId,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  // Transform RPC response to Wallet type
  const wallets: Wallet[] = (data || []).map((w: any) => ({
    id: w.id,
    wallet_type: w.wallet_type,
    balance_credits: w.balance_credits,
    lifetime_top_up_credits: w.lifetime_top_up_credits,
    cafe_id: w.cafe_id,
    cafe_name: w.cafe_name,
    network_id: w.network_id,
    network_name: w.network_name,
    created_at: w.created_at,
  }));

  return { data: wallets, error: null };
}

/**
 * Получает транзакции кошелька
 * UPDATED: 2026-02-05 - Direct query (get_wallet_transactions deprecated)
 */
export async function getWalletTransactions(
  walletId: string,
  limit: number = 50,
  offset: number = 0
) {
  const supabase = createAdminClient();

  const { data, error } = await supabase
    .from("wallet_transactions")
    .select("*")
    .eq("wallet_id", walletId)
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  return { data: data as WalletTransaction[] | null, error: error?.message };
}

/**
 * Получает статистику по кошелькам
 * NOTE: get_wallets_stats RPC deprecated - using direct aggregation
 * TODO: Create new RPC with canonical schema if needed
 */
export async function getWalletsStats() {
  const supabase = createAdminClient();

  // Direct aggregation query
  const { data, error } = await supabase
    .from("wallets")
    .select("balance_credits, wallet_type");

  if (error || !data) {
    return { data: null, error: error?.message };
  }

  // Calculate stats manually
  const stats = {
    total_wallets: data.length,
    total_balance: data.reduce((sum, w) => sum + (w.balance_credits || 0), 0),
    avg_balance: data.length > 0 
      ? Math.round(data.reduce((sum, w) => sum + (w.balance_credits || 0), 0) / data.length)
      : 0,
    citypass_count: data.filter(w => w.wallet_type === "citypass").length,
    cafe_wallet_count: data.filter(w => w.wallet_type === "cafe_wallet").length,
  };

  return { data: stats, error: null };
}
