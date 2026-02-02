import { createAdminClient } from "../admin";

/**
 * Получает метрики для dashboard
 */
export async function getDashboardMetrics(cafeId?: string) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_dashboard_metrics", {
    cafe_id_param: cafeId || null,
  });

  return { data, error: error?.message };
}

/**
 * Получает выручку по дням
 */
export async function getRevenueByDay(cafeId?: string, days: number = 30) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_revenue_by_day", {
    cafe_id_param: cafeId || null,
    days_param: days,
  });

  return { data, error: error?.message };
}

/**
 * Получает топ позиций меню
 */
export async function getTopMenuItems(cafeId?: string, limit: number = 10) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_top_menu_items", {
    cafe_id_param: cafeId || null,
    limit_param: limit,
  });

  return { data, error: error?.message };
}

/**
 * Получает статистику кафе за период
 */
export async function getCafeStats(
  cafeId?: string,
  fromDate?: string,
  toDate?: string
) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_cafe_stats", {
    cafe_id_param: cafeId || null,
    from_date: fromDate || null,
    to_date: toDate || null,
  });

  return { data, error: error?.message };
}

/**
 * Получает статистику заказов по часам дня
 */
export async function getHourlyOrdersStats(
  cafeId: string,
  dateFrom?: string,
  dateTo?: string
) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_hourly_orders_stats", {
    cafe_id_param: cafeId,
    date_from: dateFrom || null,
    date_to: dateTo || null,
  });

  return { data, error: error?.message };
}

/**
 * Получает статистику конверсии и эффективности
 */
export async function getCafeConversionStats(
  cafeId: string,
  dateFrom?: string,
  dateTo?: string
) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_cafe_conversion_stats", {
    cafe_id_param: cafeId,
    date_from: dateFrom || null,
    date_to: dateTo || null,
  });

  return { data, error: error?.message };
}

/**
 * Получает сравнение между двумя периодами
 */
export async function getPeriodComparison(
  cafeId: string,
  currentFrom: string,
  currentTo: string,
  previousFrom: string,
  previousTo: string
) {
  const supabase = createAdminClient();

  const { data, error } = await supabase.rpc("get_period_comparison", {
    cafe_id_param: cafeId,
    current_from: currentFrom,
    current_to: currentTo,
    previous_from: previousFrom,
    previous_to: previousTo,
  });

  return { data, error: error?.message };
}
