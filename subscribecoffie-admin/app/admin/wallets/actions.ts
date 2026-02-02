"use server";

import { revalidatePath } from "next/cache";

import { createAdminClient } from "../../../lib/supabase/admin";
import { requireAdmin } from "../../../lib/supabase/roles";

/**
 * Добавляет ручную транзакцию (начисление или списание)
 */
export async function addManualTransaction(
  userId: string,
  amount: number,
  type: "credit" | "debit",
  reason: string
) {
  const { userId: adminId } = await requireAdmin();
  const supabase = createAdminClient();

  // Определяем тип транзакции
  const transactionType = type === "credit" ? "admin_credit" : "admin_debit";

  const { data, error } = await supabase.rpc("add_wallet_transaction", {
    user_id_param: userId,
    amount_param: Math.abs(amount),
    type_param: transactionType,
    description_param: `Ручная операция: ${reason}`,
    actor_user_id_param: adminId,
  });

  if (error) {
    throw new Error(`Failed to add transaction: ${error.message}`);
  }

  revalidatePath("/admin/wallets");
  revalidatePath(`/admin/wallets/${userId}`);

  return data;
}

/**
 * Пересчитывает баланс кошелька
 */
export async function syncWalletBalance(walletId: string) {
  await requireAdmin();
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("sync_wallet_balance", {
    wallet_id_param: walletId,
  });

  if (error) {
    throw new Error(`Failed to sync wallet balance: ${error.message}`);
  }

  revalidatePath("/admin/wallets");

  return data;
}

/**
 * Получает кошелек пользователя
 */
export async function getUserWallet(userId: string) {
  await requireAdmin();
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_user_wallet", {
    user_id_param: userId,
  });

  if (error) {
    throw new Error(`Failed to get wallet: ${error.message}`);
  }

  return data;
}

/**
 * Получает транзакции кошелька
 */
export async function getUserTransactions(
  userId: string,
  limit: number = 50,
  offset: number = 0
) {
  await requireAdmin();
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_wallet_transactions", {
    user_id_param: userId,
    limit_param: limit,
    offset_param: offset,
  });

  if (error) {
    throw new Error(`Failed to get transactions: ${error.message}`);
  }

  return data;
}
