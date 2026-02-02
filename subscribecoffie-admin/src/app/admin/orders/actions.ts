"use server";

import { revalidatePath } from "next/cache";

import { createAdminClient } from "../../../lib/supabase/admin";
import { createServerClient } from "../../../lib/supabase/server";

type RedeemResult = {
  ok: boolean;
  error?: string;
  orderId?: string;
  status?: string;
  issuedAt?: string | null;
};

const mapRpcError = (message: string) => {
  const normalized = message.toLowerCase();
  if (normalized.includes("token not found")) {
    return "Токен не найден. Проверьте код.";
  }
  if (normalized.includes("token already used")) {
    return "Этот токен уже использован.";
  }
  if (normalized.includes("token expired")) {
    return "Срок действия токена истёк.";
  }
  if (normalized.includes("order not ready")) {
    return "Заказ ещё не готов к выдаче.";
  }
  if (normalized.includes("order not found")) {
    return "Заказ не найден.";
  }
  if (normalized.includes("forbidden")) {
    return "Недостаточно прав для выдачи заказа.";
  }
  if (normalized.includes("token required")) {
    return "Введите токен из QR-кода.";
  }
  return "Не удалось выдать заказ. Попробуйте снова.";
};

export async function redeemOrderByQr(token: string): Promise<RedeemResult> {
  if (!token || token.trim().length === 0) {
    return { ok: false, error: "Введите токен из QR-кода." };
  }

  const supabase = await createServerClient();
  const { data: claimsData, error: claimsError } =
    await supabase.auth.getClaims();

  if (claimsError || !claimsData?.claims) {
    return { ok: false, error: "Требуется вход в систему." };
  }

  const userId = claimsData.claims.sub;
  const { data: profileData, error: profileError } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .limit(1)
    .maybeSingle();

  if (profileError || profileData?.role !== "admin") {
    return { ok: false, error: "Недостаточно прав для выдачи заказа." };
  }

  try {
    const adminClient = createAdminClient();
    const { data, error } = await adminClient.rpc("redeem_order_qr", {
      p_token: token.trim(),
      p_actor_user_id: userId,
    });

    if (error) {
      return { ok: false, error: mapRpcError(error.message) };
    }

    const record = Array.isArray(data) ? data[0] : data;

    revalidatePath("/admin/orders");

    return {
      ok: true,
      orderId: record?.order_id ?? undefined,
      status: record?.status ?? undefined,
      issuedAt: record?.issued_at ?? null,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return { ok: false, error: mapRpcError(message) };
  }
}
