"use server";

import { revalidatePath } from "next/cache";

import { createServerClient } from "../../../lib/supabase/server";
import { requireAdmin } from "../../../lib/supabase/roles";

/**
 * Обновляет статус заказа
 */
export async function updateOrderStatus(orderId: string, newStatus: string) {
  const { userId } = await requireAdmin();
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("update_order_status", {
    order_id: orderId,
    new_status: newStatus,
    actor_user_id: userId,
  });

  if (error) {
    throw new Error(`Failed to update order status: ${error.message}`);
  }

  revalidatePath("/admin/orders");
  revalidatePath(`/admin/orders/${orderId}`);

  return data;
}

/**
 * Получает детали заказа с items и историей
 */
export async function getOrderDetails(orderId: string) {
  await requireAdmin();
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("get_order_details", {
    order_id_param: orderId,
  });

  if (error) {
    throw new Error(`Failed to get order details: ${error.message}`);
  }

  return data;
}

/**
 * Получает список заказов с фильтрацией
 */
export async function getOrders(options?: {
  cafeId?: string;
  status?: string;
  limit?: number;
  offset?: number;
}) {
  await requireAdmin();
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("get_orders_by_cafe", {
    cafe_id_param: options?.cafeId || null,
    status_filter: options?.status || null,
    limit_param: options?.limit || 50,
    offset_param: options?.offset || 0,
  });

  if (error) {
    throw new Error(`Failed to get orders: ${error.message}`);
  }

  return data;
}

/**
 * Получает статистику заказов
 */
export async function getOrdersStats(options?: {
  cafeId?: string;
  fromDate?: string;
  toDate?: string;
}) {
  await requireAdmin();
  const supabase = await createServerClient();

  const { data, error } = await supabase.rpc("get_orders_stats", {
    cafe_id_param: options?.cafeId || null,
    from_date: options?.fromDate || null,
    to_date: options?.toDate || null,
  });

  if (error) {
    throw new Error(`Failed to get orders stats: ${error.message}`);
  }

  return data;
}
