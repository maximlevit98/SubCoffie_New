import { createServerClient } from "../server";
import type {
  AdminWallet,
  AdminWalletOrder,
  AdminWalletOverview,
  AdminWalletPayment,
  AdminWalletTransaction,
} from "./wallets";

type OwnerCafe = {
  id: string;
  name: string | null;
};

export type OwnerWalletsStats = {
  total_wallets: number;
  total_balance_credits: number;
  total_lifetime_topup_credits: number;
  total_transactions: number;
  total_orders: number;
  total_revenue_credits: number;
  avg_wallet_balance: number;
  active_wallets_30d: number;
  total_topup_credits: number;
  total_spent_credits: number;
  total_refund_credits: number;
  net_wallet_change_credits: number;
};

type WalletBaseRow = {
  id: string;
  user_id: string;
  wallet_type: "citypass" | "cafe_wallet";
  balance_credits: number | null;
  lifetime_top_up_credits: number | null;
  created_at: string;
  updated_at: string;
  cafe_id: string | null;
};

type WalletTransactionRow = {
  id: string;
  wallet_id: string;
  amount: number;
  type: string;
  description: string | null;
  order_id: string | null;
  actor_user_id: string | null;
  balance_before: number;
  balance_after: number;
  created_at: string;
};

type PaymentRow = {
  id: string;
  wallet_id: string;
  order_id: string | null;
  amount_credits: number;
  commission_credits: number;
  transaction_type: string;
  payment_method_id: string | null;
  status: string;
  provider_transaction_id: string | null;
  idempotency_key: string | null;
  created_at: string;
  completed_at: string | null;
};

type OrderRow = {
  id: string;
  order_number: string | null;
  created_at: string;
  status: string;
  cafe_id: string;
  subtotal_credits: number | null;
  paid_credits: number | null;
  bonus_used: number | null;
  payment_method: string | null;
  payment_status: string | null;
  customer_name: string | null;
  customer_phone: string | null;
  wallet_id: string | null;
};

type OrderItemRow = {
  id: string;
  order_id: string;
  item_name: string | null;
  quantity: number | null;
  unit_credits: number | null;
  total_price_credits: number | null;
  modifiers: unknown;
};

type ProfileRow = {
  id: string;
  email: string | null;
  phone: string | null;
  full_name: string | null;
  avatar_url: string | null;
  created_at: string;
};

type WalletLookup = {
  wallet: WalletBaseRow;
};

function isMissingRpcError(message?: string): boolean {
  if (!message) return false;
  return (
    message.includes("does not exist") ||
    message.includes("Could not find the function") ||
    message.includes("schema cache")
  );
}

function normalizeError(error: unknown, fallback = "Unknown error"): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return fallback;
}

async function getOwnerCafes() {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("get_owner_cafes");

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data || []) as OwnerCafe[], error: null };
}

async function getOwnedWalletById(walletId: string): Promise<{
  data: WalletLookup | null;
  error: string | null;
}> {
  const supabase = await createServerClient();
  const { data: cafes, error: cafesError } = await getOwnerCafes();
  if (cafesError) {
    return { data: null, error: cafesError };
  }

  const ownedCafeIds = (cafes || []).map((c) => c.id);
  if (ownedCafeIds.length === 0) {
    return { data: null, error: "У владельца нет кофеен" };
  }

  const { data: wallet, error: walletError } = await supabase
    .from("wallets")
    .select(
      "id,user_id,wallet_type,balance_credits,lifetime_top_up_credits,created_at,updated_at,cafe_id"
    )
    .eq("id", walletId)
    .eq("wallet_type", "cafe_wallet")
    .maybeSingle();

  if (walletError) {
    return { data: null, error: walletError.message };
  }

  if (!wallet) {
    return { data: null, error: "Кошелёк не найден" };
  }

  if (!wallet.cafe_id || !ownedCafeIds.includes(wallet.cafe_id)) {
    return { data: null, error: "Unauthorized: wallet not accessible" };
  }

  return {
    data: {
      wallet: wallet as WalletBaseRow,
    },
    error: null,
  };
}

function toInt(value: number | null | undefined): number {
  return typeof value === "number" ? value : 0;
}

export async function listOwnerWallets(options?: {
  cafeId?: string;
  limit?: number;
  offset?: number;
  search?: string;
}): Promise<{ data: AdminWallet[] | null; error: string | null }> {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallets", {
    p_cafe_id: options?.cafeId || null,
    p_limit: options?.limit || 50,
    p_offset: options?.offset || 0,
    p_search: options?.search || null,
  });

  if (!error) {
    const normalized = ((data || []) as Partial<AdminWallet>[]).map((row) => ({
      wallet_id: row.wallet_id || "",
      user_id: row.user_id || "",
      wallet_type: (row.wallet_type as "citypass" | "cafe_wallet") || "cafe_wallet",
      balance_credits: toInt(row.balance_credits),
      lifetime_top_up_credits: toInt(row.lifetime_top_up_credits),
      created_at: row.created_at || new Date(0).toISOString(),
      user_email: row.user_email || null,
      user_phone: row.user_phone || null,
      user_full_name: row.user_full_name || null,
      cafe_id: row.cafe_id || null,
      cafe_name: row.cafe_name || null,
      network_id: row.network_id || null,
      network_name: row.network_name || null,
      last_transaction_at: row.last_transaction_at || null,
      last_payment_at: row.last_payment_at || null,
      last_order_at: row.last_order_at || null,
      total_transactions: toInt(row.total_transactions),
      total_payments: toInt(row.total_payments),
      total_orders: toInt(row.total_orders),
      total_topups: toInt(row.total_topups),
      total_refunds: toInt(row.total_refunds),
      total_topup_credits: toInt(row.total_topup_credits),
      total_spent_credits: toInt(row.total_spent_credits),
      total_refund_credits: toInt(row.total_refund_credits),
      net_wallet_change_credits: toInt(row.net_wallet_change_credits),
      total_orders_paid_credits: toInt(row.total_orders_paid_credits),
    }));
    return { data: normalized, error: null };
  }

  if (!isMissingRpcError(error.message)) {
    return { data: null, error: error.message };
  }

  // Fallback for environments where migration was not applied yet.
  const { data: cafes, error: cafesError } = await getOwnerCafes();
  if (cafesError) {
    return { data: null, error: cafesError };
  }

  const cafeIds = (cafes || []).map((c) => c.id);
  if (cafeIds.length === 0) {
    return { data: [], error: null };
  }

  const { data: walletRows, error: walletsError } = await supabase
    .from("wallets")
    .select(
      "id,user_id,wallet_type,balance_credits,lifetime_top_up_credits,created_at,updated_at,cafe_id"
    )
    .eq("wallet_type", "cafe_wallet")
    .in("cafe_id", options?.cafeId ? [options.cafeId] : cafeIds)
    .order("created_at", { ascending: false });

  if (walletsError) {
    return { data: null, error: walletsError.message };
  }

  const wallets = (walletRows || []) as WalletBaseRow[];
  if (wallets.length === 0) {
    return { data: [], error: null };
  }

  const walletIds = wallets.map((w) => w.id);
  const userIds = [...new Set(wallets.map((w) => w.user_id))];

  const [{ data: profiles }, { data: txRows }, { data: paymentRows }, { data: orderRows }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("id,email,phone,full_name,avatar_url,created_at")
        .in("id", userIds),
      supabase
        .from("wallet_transactions")
        .select("id,wallet_id,amount,type,description,order_id,actor_user_id,balance_before,balance_after,created_at")
        .in("wallet_id", walletIds),
      supabase
        .from("payment_transactions")
        .select("id,wallet_id,order_id,amount_credits,commission_credits,transaction_type,payment_method_id,status,provider_transaction_id,idempotency_key,created_at,completed_at")
        .in("wallet_id", walletIds),
      supabase
        .from("orders_core")
        .select("id,order_number,created_at,status,cafe_id,subtotal_credits,paid_credits,bonus_used,payment_method,payment_status,customer_name,customer_phone,wallet_id")
        .in("wallet_id", walletIds),
    ]);

  const cafesMap = new Map((cafes || []).map((c) => [c.id, c.name]));
  const profilesMap = new Map(
    ((profiles || []) as ProfileRow[]).map((p) => [p.id, p])
  );

  const txByWallet = new Map<string, WalletTransactionRow[]>();
  for (const tx of (txRows || []) as WalletTransactionRow[]) {
    const list = txByWallet.get(tx.wallet_id) || [];
    list.push(tx);
    txByWallet.set(tx.wallet_id, list);
  }

  const paymentsByWallet = new Map<string, PaymentRow[]>();
  for (const payment of (paymentRows || []) as PaymentRow[]) {
    const list = paymentsByWallet.get(payment.wallet_id) || [];
    list.push(payment);
    paymentsByWallet.set(payment.wallet_id, list);
  }

  const ordersByWallet = new Map<string, OrderRow[]>();
  for (const order of (orderRows || []) as OrderRow[]) {
    const walletId = order.wallet_id;
    if (!walletId) continue;
    const list = ordersByWallet.get(walletId) || [];
    list.push(order);
    ordersByWallet.set(walletId, list);
  }

  const transformed: AdminWallet[] = wallets.map((wallet) => {
    const profile = profilesMap.get(wallet.user_id);
    const tx = txByWallet.get(wallet.id) || [];
    const payments = paymentsByWallet.get(wallet.id) || [];
    const orders = ordersByWallet.get(wallet.id) || [];

    const topups = tx.filter((item) => item.type === "topup");
    const refunds = tx.filter((item) => item.type === "refund");
    const paymentsTx = tx.filter((item) => item.type === "payment");

    const lastTransactionAt = tx
      .map((item) => item.created_at)
      .sort()
      .at(-1) || null;
    const lastPaymentAt = payments
      .filter((item) => item.status === "completed" && item.completed_at)
      .map((item) => item.completed_at as string)
      .sort()
      .at(-1) || null;
    const lastOrderAt = orders
      .map((item) => item.created_at)
      .sort()
      .at(-1) || null;

    const totalTopupCredits = topups.reduce((sum, item) => sum + toInt(item.amount), 0);
    const totalSpentCredits = paymentsTx.reduce(
      (sum, item) => sum + Math.abs(toInt(item.amount)),
      0
    );
    const totalRefundCredits = refunds.reduce(
      (sum, item) => sum + toInt(item.amount),
      0
    );
    const netWalletChangeCredits = tx.reduce(
      (sum, item) => sum + toInt(item.amount),
      0
    );
    const totalOrdersPaidCredits = orders.reduce(
      (sum, order) => sum + toInt(order.paid_credits),
      0
    );

    return {
      wallet_id: wallet.id,
      user_id: wallet.user_id,
      wallet_type: wallet.wallet_type,
      balance_credits: toInt(wallet.balance_credits),
      lifetime_top_up_credits: toInt(wallet.lifetime_top_up_credits),
      created_at: wallet.created_at,
      user_email: profile?.email || null,
      user_phone: profile?.phone || null,
      user_full_name: profile?.full_name || null,
      cafe_id: wallet.cafe_id,
      cafe_name: wallet.cafe_id ? cafesMap.get(wallet.cafe_id) || null : null,
      network_id: null,
      network_name: null,
      last_transaction_at: lastTransactionAt,
      last_payment_at: lastPaymentAt,
      last_order_at: lastOrderAt,
      total_transactions: tx.length,
      total_payments: payments.length,
      total_orders: orders.length,
      total_topups: topups.length,
      total_refunds: refunds.length,
      total_topup_credits: totalTopupCredits,
      total_spent_credits: totalSpentCredits,
      total_refund_credits: totalRefundCredits,
      net_wallet_change_credits: netWalletChangeCredits,
      total_orders_paid_credits: totalOrdersPaidCredits,
    };
  });

  const search = (options?.search || "").trim().toLowerCase();
  const filtered = search
    ? transformed.filter((wallet) => {
        const haystack = [
          wallet.user_email || "",
          wallet.user_phone || "",
          wallet.user_full_name || "",
          wallet.cafe_name || "",
        ]
          .join(" ")
          .toLowerCase();
        return haystack.includes(search);
      })
    : transformed;

  const offset = options?.offset || 0;
  const limit = options?.limit || 50;
  const pageSlice = filtered.slice(offset, offset + limit);

  return { data: pageSlice, error: null };
}

export async function getOwnerWalletsStats(
  cafeId?: string
): Promise<{ data: OwnerWalletsStats | null; error: string | null }> {
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("owner_get_wallets_stats", {
    p_cafe_id: cafeId || null,
  });

  if (!error) {
    const row = (data?.[0] || {}) as Partial<OwnerWalletsStats>;
    return {
      data: {
        total_wallets: toInt(row.total_wallets),
        total_balance_credits: toInt(row.total_balance_credits),
        total_lifetime_topup_credits: toInt(row.total_lifetime_topup_credits),
        total_transactions: toInt(row.total_transactions),
        total_orders: toInt(row.total_orders),
        total_revenue_credits: toInt(row.total_revenue_credits),
        avg_wallet_balance: toInt(row.avg_wallet_balance),
        active_wallets_30d: toInt(row.active_wallets_30d),
        total_topup_credits: toInt(row.total_topup_credits),
        total_spent_credits: toInt(row.total_spent_credits),
        total_refund_credits: toInt(row.total_refund_credits),
        net_wallet_change_credits: toInt(row.net_wallet_change_credits),
      },
      error: null,
    };
  }

  if (!isMissingRpcError(error.message)) {
    return { data: null, error: error.message };
  }

  const listResult = await listOwnerWallets({
    cafeId,
    limit: 500,
    offset: 0,
  });
  if (listResult.error) {
    return { data: null, error: listResult.error };
  }

  const wallets = listResult.data || [];
  const stats: OwnerWalletsStats = {
    total_wallets: wallets.length,
    total_balance_credits: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.balance_credits),
      0
    ),
    total_lifetime_topup_credits: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.lifetime_top_up_credits),
      0
    ),
    total_transactions: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.total_transactions),
      0
    ),
    total_orders: wallets.reduce((sum, wallet) => sum + toInt(wallet.total_orders), 0),
    total_revenue_credits: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.total_orders_paid_credits),
      0
    ),
    avg_wallet_balance:
      wallets.length > 0
        ? Math.round(
            wallets.reduce(
              (sum, wallet) => sum + toInt(wallet.balance_credits),
              0
            ) / wallets.length
          )
        : 0,
    active_wallets_30d: wallets.filter((wallet) => {
      const timestamp = wallet.last_transaction_at;
      if (!timestamp) return false;
      const date = new Date(timestamp).getTime();
      const limitDate = Date.now() - 30 * 24 * 60 * 60 * 1000;
      return date >= limitDate;
    }).length,
    total_topup_credits: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.total_topup_credits),
      0
    ),
    total_spent_credits: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.total_spent_credits),
      0
    ),
    total_refund_credits: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.total_refund_credits),
      0
    ),
    net_wallet_change_credits: wallets.reduce(
      (sum, wallet) => sum + toInt(wallet.net_wallet_change_credits),
      0
    ),
  };

  return { data: stats, error: null };
}

export async function getOwnerWalletOverview(walletId: string): Promise<{
  data: AdminWalletOverview | null;
  error: string | null;
}> {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("owner_get_wallet_overview", {
    p_wallet_id: walletId,
  });

  if (!error) {
    const row = (data?.[0] || null) as Partial<AdminWalletOverview> | null;
    if (!row) {
      return { data: null, error: null };
    }
    const overview: AdminWalletOverview = {
      wallet_id: row.wallet_id || "",
      user_id: row.user_id || "",
      wallet_type: (row.wallet_type as "citypass" | "cafe_wallet") || "cafe_wallet",
      balance_credits: toInt(row.balance_credits),
      lifetime_top_up_credits: toInt(row.lifetime_top_up_credits),
      created_at: row.created_at || new Date(0).toISOString(),
      updated_at: row.updated_at || row.created_at || new Date(0).toISOString(),
      user_email: row.user_email || null,
      user_phone: row.user_phone || null,
      user_full_name: row.user_full_name || null,
      user_avatar_url: row.user_avatar_url || null,
      user_registered_at: row.user_registered_at || row.created_at || new Date(0).toISOString(),
      cafe_id: row.cafe_id || null,
      cafe_name: row.cafe_name || null,
      cafe_address: row.cafe_address || null,
      network_id: row.network_id || null,
      network_name: row.network_name || null,
      total_transactions: toInt(row.total_transactions),
      total_topups: toInt(row.total_topups),
      total_payments: toInt(row.total_payments),
      total_refunds: toInt(row.total_refunds),
      total_orders: toInt(row.total_orders),
      completed_orders: toInt(row.completed_orders),
      last_transaction_at: row.last_transaction_at || null,
      last_payment_at: row.last_payment_at || null,
      last_order_at: row.last_order_at || null,
      total_topup_credits: toInt(row.total_topup_credits),
      total_payment_credits: toInt(row.total_payment_credits),
      total_refund_credits: toInt(row.total_refund_credits),
      total_adjustment_credits: toInt(row.total_adjustment_credits),
      net_wallet_change_credits: toInt(row.net_wallet_change_credits),
      total_orders_paid_credits: toInt(row.total_orders_paid_credits),
      avg_order_paid_credits: toInt(row.avg_order_paid_credits),
      last_topup_at: row.last_topup_at || null,
      last_refund_at: row.last_refund_at || null,
    };
    return { data: overview, error: null };
  }

  if (!isMissingRpcError(error.message)) {
    return { data: null, error: error.message };
  }

  const ownership = await getOwnedWalletById(walletId);
  if (ownership.error || !ownership.data) {
    return { data: null, error: ownership.error || "Кошелёк недоступен" };
  }

  const wallet = ownership.data.wallet;
  const { data: profile } = await supabase
    .from("profiles")
    .select("id,email,phone,full_name,avatar_url,created_at")
    .eq("id", wallet.user_id)
    .maybeSingle();

  const { data: cafe } = await supabase
    .from("cafes")
    .select("id,name,address")
    .eq("id", wallet.cafe_id as string)
    .maybeSingle();

  const [{ data: txRows }, { data: paymentRows }, { data: orderRows }] = await Promise.all([
    supabase
      .from("wallet_transactions")
      .select("id,wallet_id,amount,type,description,order_id,actor_user_id,balance_before,balance_after,created_at")
      .eq("wallet_id", wallet.id),
    supabase
      .from("payment_transactions")
      .select("id,wallet_id,order_id,amount_credits,commission_credits,transaction_type,payment_method_id,status,provider_transaction_id,idempotency_key,created_at,completed_at")
      .eq("wallet_id", wallet.id),
    supabase
      .from("orders_core")
      .select("id,order_number,created_at,status,cafe_id,subtotal_credits,paid_credits,bonus_used,payment_method,payment_status,customer_name,customer_phone,wallet_id")
      .eq("wallet_id", wallet.id),
  ]);

  const tx = (txRows || []) as WalletTransactionRow[];
  const payments = (paymentRows || []) as PaymentRow[];
  const orders = (orderRows || []) as OrderRow[];

  const topups = tx.filter((item) => item.type === "topup");
  const paymentTx = tx.filter((item) => item.type === "payment");
  const refunds = tx.filter((item) => item.type === "refund");
  const adjustments = tx.filter(
    (item) => item.type === "admin_credit" || item.type === "admin_debit"
  );

  const lastTransactionAt = tx.map((item) => item.created_at).sort().at(-1) || null;
  const lastTopupAt = topups.map((item) => item.created_at).sort().at(-1) || null;
  const lastRefundAt = refunds.map((item) => item.created_at).sort().at(-1) || null;
  const lastPaymentAt = payments
    .filter((item) => item.status === "completed" && item.completed_at)
    .map((item) => item.completed_at as string)
    .sort()
    .at(-1) || null;
  const lastOrderAt = orders.map((item) => item.created_at).sort().at(-1) || null;

  const totalTopupCredits = topups.reduce((sum, item) => sum + toInt(item.amount), 0);
  const totalPaymentCredits = paymentTx.reduce(
    (sum, item) => sum + Math.abs(toInt(item.amount)),
    0
  );
  const totalRefundCredits = refunds.reduce(
    (sum, item) => sum + toInt(item.amount),
    0
  );
  const totalAdjustmentCredits = adjustments.reduce(
    (sum, item) => sum + toInt(item.amount),
    0
  );
  const netWalletChangeCredits = tx.reduce((sum, item) => sum + toInt(item.amount), 0);
  const totalOrdersPaidCredits = orders.reduce(
    (sum, order) => sum + toInt(order.paid_credits),
    0
  );
  const completedOrders = orders.filter((order) =>
    ["issued", "picked_up"].includes(order.status)
  ).length;

  const overview: AdminWalletOverview = {
    wallet_id: wallet.id,
    user_id: wallet.user_id,
    wallet_type: wallet.wallet_type,
    balance_credits: toInt(wallet.balance_credits),
    lifetime_top_up_credits: toInt(wallet.lifetime_top_up_credits),
    created_at: wallet.created_at,
    updated_at: wallet.updated_at,
    user_email: (profile as ProfileRow | null)?.email || null,
    user_phone: (profile as ProfileRow | null)?.phone || null,
    user_full_name: (profile as ProfileRow | null)?.full_name || null,
    user_avatar_url: (profile as ProfileRow | null)?.avatar_url || null,
    user_registered_at:
      (profile as ProfileRow | null)?.created_at || wallet.created_at,
    cafe_id: wallet.cafe_id,
    cafe_name: (cafe as { name: string | null } | null)?.name || null,
    cafe_address: (cafe as { address: string | null } | null)?.address || null,
    network_id: null,
    network_name: null,
    total_transactions: tx.length,
    total_topups: topups.length,
    total_payments: paymentTx.length,
    total_refunds: refunds.length,
    total_orders: orders.length,
    completed_orders: completedOrders,
    last_transaction_at: lastTransactionAt,
    last_payment_at: lastPaymentAt,
    last_order_at: lastOrderAt,
    total_topup_credits: totalTopupCredits,
    total_payment_credits: totalPaymentCredits,
    total_refund_credits: totalRefundCredits,
    total_adjustment_credits: totalAdjustmentCredits,
    net_wallet_change_credits: netWalletChangeCredits,
    total_orders_paid_credits: totalOrdersPaidCredits,
    avg_order_paid_credits:
      orders.length > 0 ? Math.round(totalOrdersPaidCredits / orders.length) : 0,
    last_topup_at: lastTopupAt,
    last_refund_at: lastRefundAt,
  };

  return { data: overview, error: null };
}

export async function getOwnerWalletTransactions(
  walletId: string,
  limit: number = 50,
  offset: number = 0
): Promise<{ data: AdminWalletTransaction[] | null; error: string | null }> {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("owner_get_wallet_transactions", {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset,
  });

  if (!error) {
    return { data: (data || []) as AdminWalletTransaction[], error: null };
  }

  if (!isMissingRpcError(error.message)) {
    return { data: null, error: error.message };
  }

  const ownership = await getOwnedWalletById(walletId);
  if (ownership.error || !ownership.data) {
    return { data: null, error: ownership.error || "Кошелёк недоступен" };
  }

  const { data: txRows, error: txError } = await supabase
    .from("wallet_transactions")
    .select("id,wallet_id,amount,type,description,order_id,actor_user_id,balance_before,balance_after,created_at")
    .eq("wallet_id", walletId)
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (txError) {
    return { data: null, error: txError.message };
  }

  const tx = (txRows || []) as WalletTransactionRow[];
  const orderIds = [...new Set(tx.map((item) => item.order_id).filter(Boolean))] as string[];
  const actorIds = [...new Set(tx.map((item) => item.actor_user_id).filter(Boolean))] as string[];

  const [{ data: orders }, { data: actors }] = await Promise.all([
    orderIds.length
      ? supabase.from("orders_core").select("id,order_number").in("id", orderIds)
      : Promise.resolve({ data: [] as Array<{ id: string; order_number: string | null }> }),
    actorIds.length
      ? supabase
          .from("profiles")
          .select("id,email,full_name")
          .in("id", actorIds)
      : Promise.resolve({ data: [] as Array<{ id: string; email: string | null; full_name: string | null }> }),
  ]);

  const orderMap = new Map(
    ((orders || []) as Array<{ id: string; order_number: string | null }>).map((o) => [
      o.id,
      o.order_number,
    ])
  );
  const actorMap = new Map(
    ((actors || []) as Array<{ id: string; email: string | null; full_name: string | null }>).map((a) => [
      a.id,
      a,
    ])
  );

  const mapped: AdminWalletTransaction[] = tx.map((item) => {
    const actor = item.actor_user_id ? actorMap.get(item.actor_user_id) : null;
    return {
      transaction_id: item.id,
      wallet_id: item.wallet_id,
      amount: item.amount,
      type: item.type,
      description: item.description,
      order_id: item.order_id,
      order_number: item.order_id ? orderMap.get(item.order_id) || null : null,
      actor_user_id: item.actor_user_id,
      actor_email: actor?.email || null,
      actor_full_name: actor?.full_name || null,
      balance_before: item.balance_before,
      balance_after: item.balance_after,
      created_at: item.created_at,
    };
  });

  return { data: mapped, error: null };
}

export async function getOwnerWalletPayments(
  walletId: string,
  limit: number = 50,
  offset: number = 0
): Promise<{ data: AdminWalletPayment[] | null; error: string | null }> {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("owner_get_wallet_payments", {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset,
  });

  if (!error) {
    return { data: (data || []) as AdminWalletPayment[], error: null };
  }

  if (!isMissingRpcError(error.message)) {
    return { data: null, error: error.message };
  }

  const ownership = await getOwnedWalletById(walletId);
  if (ownership.error || !ownership.data) {
    return { data: null, error: ownership.error || "Кошелёк недоступен" };
  }

  const { data: paymentsRows, error: paymentsError } = await supabase
    .from("payment_transactions")
    .select(
      "id,wallet_id,order_id,amount_credits,commission_credits,transaction_type,payment_method_id,status,provider_transaction_id,idempotency_key,created_at,completed_at"
    )
    .eq("wallet_id", walletId)
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (paymentsError) {
    return { data: null, error: paymentsError.message };
  }

  const payments = (paymentsRows || []) as PaymentRow[];
  const orderIds = [...new Set(payments.map((item) => item.order_id).filter(Boolean))] as string[];
  const { data: orders } = orderIds.length
    ? await supabase.from("orders_core").select("id,order_number").in("id", orderIds)
    : { data: [] as Array<{ id: string; order_number: string | null }> };
  const orderMap = new Map(
    ((orders || []) as Array<{ id: string; order_number: string | null }>).map((order) => [
      order.id,
      order.order_number,
    ])
  );

  const mapped: AdminWalletPayment[] = payments.map((payment) => ({
    payment_id: payment.id,
    wallet_id: payment.wallet_id,
    order_id: payment.order_id,
    order_number: payment.order_id ? orderMap.get(payment.order_id) || null : null,
    amount_credits: payment.amount_credits,
    commission_credits: payment.commission_credits,
    net_amount: payment.amount_credits - payment.commission_credits,
    transaction_type: payment.transaction_type,
    payment_method_id: payment.payment_method_id,
    status: payment.status,
    provider_transaction_id: payment.provider_transaction_id,
    idempotency_key: payment.idempotency_key,
    created_at: payment.created_at,
    completed_at: payment.completed_at,
  }));

  return { data: mapped, error: null };
}

export async function getOwnerWalletOrders(
  walletId: string,
  limit: number = 50,
  offset: number = 0
): Promise<{ data: AdminWalletOrder[] | null; error: string | null }> {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("owner_get_wallet_orders", {
    p_wallet_id: walletId,
    p_limit: limit,
    p_offset: offset,
  });

  if (!error) {
    return { data: (data || []) as AdminWalletOrder[], error: null };
  }

  if (!isMissingRpcError(error.message)) {
    return { data: null, error: error.message };
  }

  const ownership = await getOwnedWalletById(walletId);
  if (ownership.error || !ownership.data) {
    return { data: null, error: ownership.error || "Кошелёк недоступен" };
  }

  const { data: orderRows, error: ordersError } = await supabase
    .from("orders_core")
    .select(
      "id,order_number,created_at,status,cafe_id,subtotal_credits,paid_credits,bonus_used,payment_method,payment_status,customer_name,customer_phone,wallet_id"
    )
    .eq("wallet_id", walletId)
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (ordersError) {
    return { data: null, error: ordersError.message };
  }

  const orders = (orderRows || []) as OrderRow[];
  const orderIds = orders.map((order) => order.id);
  const cafeIds = [...new Set(orders.map((order) => order.cafe_id))];

  const [{ data: cafeRows }, { data: itemRows }] = await Promise.all([
    cafeIds.length
      ? supabase.from("cafes").select("id,name").in("id", cafeIds)
      : Promise.resolve({ data: [] as Array<{ id: string; name: string | null }> }),
    orderIds.length
      ? supabase
          .from("order_items")
          .select("id,order_id,item_name,quantity,unit_credits,total_price_credits,modifiers")
          .in("order_id", orderIds)
      : Promise.resolve({ data: [] as OrderItemRow[] }),
  ]);

  const cafeMap = new Map(
    ((cafeRows || []) as Array<{ id: string; name: string | null }>).map((cafe) => [
      cafe.id,
      cafe.name,
    ])
  );
  const itemsByOrder = new Map<string, OrderItemRow[]>();
  for (const item of (itemRows || []) as OrderItemRow[]) {
    const list = itemsByOrder.get(item.order_id) || [];
    list.push(item);
    itemsByOrder.set(item.order_id, list);
  }

  const mapped: AdminWalletOrder[] = orders.map((order) => ({
    order_id: order.id,
    order_number: order.order_number || order.id.slice(0, 8),
    created_at: order.created_at,
    status: order.status,
    cafe_id: order.cafe_id,
    cafe_name: cafeMap.get(order.cafe_id) || null,
    subtotal_credits: toInt(order.subtotal_credits),
    paid_credits: toInt(order.paid_credits),
    bonus_used: toInt(order.bonus_used),
    payment_method: order.payment_method,
    payment_status: order.payment_status,
    customer_name: order.customer_name,
    customer_phone: order.customer_phone,
    items: (itemsByOrder.get(order.id) || []).map((item) => {
      const qty = toInt(item.quantity) || 1;
      const unit = toInt(item.unit_credits);
      const line = item.total_price_credits ?? unit * qty;
      return {
        item_id: item.id,
        item_name: item.item_name || "Позиция",
        qty,
        unit_price_credits: unit,
        line_total_credits: toInt(line),
        modifiers: item.modifiers ?? null,
      };
    }),
  }));

  return { data: mapped, error: null };
}

export async function getOwnerCafesForFilters(): Promise<{
  data: OwnerCafe[] | null;
  error: string | null;
}> {
  const result = await getOwnerCafes();
  return {
    data: result.data,
    error: result.error,
  };
}

export function formatOwnerWalletError(error: unknown): string {
  return normalizeError(error, "Не удалось загрузить данные кошелька");
}
