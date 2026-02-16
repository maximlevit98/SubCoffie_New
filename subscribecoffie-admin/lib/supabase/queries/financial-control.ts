import { createServerClient } from "../server";

export type FinancialControlMetrics = {
  scope: "admin" | "owner";
  date_from: string;
  date_to: string;
  selected_cafe_id: string | null;
  topup_completed_count: number;
  topup_completed_credits: number;
  order_payment_completed_count: number;
  order_payment_completed_credits: number;
  refund_completed_count: number;
  refund_completed_credits: number;
  platform_commission_credits: number;
  pending_credits: number;
  failed_credits: number;
  wallet_balance_snapshot_credits: number;
  orders_count: number;
  completed_orders_count: number;
  orders_paid_credits: number;
  wallet_ledger_delta_credits: number;
  expected_wallet_delta_credits: number;
  discrepancy_credits: number;
};

export type FinancialAnomaly = {
  anomaly_key: string;
  severity: "critical" | "high" | "medium" | "low";
  anomaly_type: string;
  wallet_id: string | null;
  order_id: string | null;
  cafe_id: string | null;
  amount_credits: number;
  detected_at: string;
  message: string;
  details: Record<string, unknown> | null;
};

type FinancialRpcRow = Partial<FinancialControlMetrics>;
type FinancialAnomalyRpcRow = Partial<FinancialAnomaly>;

function toNumber(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function normalizeMetrics(
  row: FinancialRpcRow | null,
  fallbackScope: "admin" | "owner"
): FinancialControlMetrics {
  return {
    scope: row?.scope === "admin" || row?.scope === "owner" ? row.scope : fallbackScope,
    date_from: row?.date_from || new Date(0).toISOString(),
    date_to: row?.date_to || new Date(0).toISOString(),
    selected_cafe_id: row?.selected_cafe_id || null,
    topup_completed_count: toNumber(row?.topup_completed_count),
    topup_completed_credits: toNumber(row?.topup_completed_credits),
    order_payment_completed_count: toNumber(row?.order_payment_completed_count),
    order_payment_completed_credits: toNumber(row?.order_payment_completed_credits),
    refund_completed_count: toNumber(row?.refund_completed_count),
    refund_completed_credits: toNumber(row?.refund_completed_credits),
    platform_commission_credits: toNumber(row?.platform_commission_credits),
    pending_credits: toNumber(row?.pending_credits),
    failed_credits: toNumber(row?.failed_credits),
    wallet_balance_snapshot_credits: toNumber(row?.wallet_balance_snapshot_credits),
    orders_count: toNumber(row?.orders_count),
    completed_orders_count: toNumber(row?.completed_orders_count),
    orders_paid_credits: toNumber(row?.orders_paid_credits),
    wallet_ledger_delta_credits: toNumber(row?.wallet_ledger_delta_credits),
    expected_wallet_delta_credits: toNumber(row?.expected_wallet_delta_credits),
    discrepancy_credits: toNumber(row?.discrepancy_credits),
  };
}

function normalizeAnomaly(row: FinancialAnomalyRpcRow): FinancialAnomaly {
  const severity = row.severity;
  return {
    anomaly_key: row.anomaly_key || "unknown",
    severity:
      severity === "critical" || severity === "high" || severity === "medium" || severity === "low"
        ? severity
        : "low",
    anomaly_type: row.anomaly_type || "unknown",
    wallet_id: row.wallet_id || null,
    order_id: row.order_id || null,
    cafe_id: row.cafe_id || null,
    amount_credits: toNumber(row.amount_credits),
    detected_at: row.detected_at || new Date(0).toISOString(),
    message: row.message || "",
    details:
      row.details && typeof row.details === "object" && !Array.isArray(row.details)
        ? (row.details as Record<string, unknown>)
        : null,
  };
}

export async function getAdminFinancialControlTower(params?: {
  from?: string;
  to?: string;
  cafeId?: string;
}) {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("admin_get_financial_control_tower", {
    p_from: params?.from || null,
    p_to: params?.to || null,
    p_cafe_id: params?.cafeId || null,
  });

  if (error) {
    return { data: null as FinancialControlMetrics | null, error: error.message };
  }

  const row = ((data || [])[0] || null) as FinancialRpcRow | null;
  return { data: normalizeMetrics(row, "admin"), error: null as string | null };
}

export async function listAdminFinancialAnomalies(params?: {
  from?: string;
  to?: string;
  cafeId?: string;
  limit?: number;
}) {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("admin_get_financial_anomalies", {
    p_from: params?.from || null,
    p_to: params?.to || null,
    p_cafe_id: params?.cafeId || null,
    p_limit: params?.limit || 50,
  });

  if (error) {
    return { data: null as FinancialAnomaly[] | null, error: error.message };
  }

  const rows = (data || []) as FinancialAnomalyRpcRow[];
  return { data: rows.map(normalizeAnomaly), error: null as string | null };
}

export async function getOwnerFinancialControlTower(params?: {
  from?: string;
  to?: string;
  cafeId?: string;
}) {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("owner_get_financial_control_tower", {
    p_from: params?.from || null,
    p_to: params?.to || null,
    p_cafe_id: params?.cafeId || null,
  });

  if (error) {
    return { data: null as FinancialControlMetrics | null, error: error.message };
  }

  const row = ((data || [])[0] || null) as FinancialRpcRow | null;
  return { data: normalizeMetrics(row, "owner"), error: null as string | null };
}

export async function listOwnerFinancialAnomalies(params?: {
  from?: string;
  to?: string;
  cafeId?: string;
  limit?: number;
}) {
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("owner_get_financial_anomalies", {
    p_from: params?.from || null,
    p_to: params?.to || null,
    p_cafe_id: params?.cafeId || null,
    p_limit: params?.limit || 50,
  });

  if (error) {
    return { data: null as FinancialAnomaly[] | null, error: error.message };
  }

  const rows = (data || []) as FinancialAnomalyRpcRow[];
  return { data: rows.map(normalizeAnomaly), error: null as string | null };
}

export async function listCafesForFinancialFilters(scope: "admin" | "owner") {
  const supabase = await createServerClient();

  if (scope === "owner") {
    const { data, error } = await supabase.rpc("get_owner_cafes");
    if (error) return { data: null as Array<{ id: string; name: string | null }> | null, error: error.message };

    const cafes = ((data || []) as Array<{ id: string; name: string | null }>).map((cafe) => ({
      id: cafe.id,
      name: cafe.name || null,
    }));

    return { data: cafes, error: null as string | null };
  }

  const { data, error } = await supabase
    .from("cafes")
    .select("id,name")
    .order("name", { ascending: true });

  if (error) {
    return { data: null as Array<{ id: string; name: string | null }> | null, error: error.message };
  }

  return {
    data: ((data || []) as Array<{ id: string; name: string | null }>).map((cafe) => ({
      id: cafe.id,
      name: cafe.name || null,
    })),
    error: null as string | null,
  };
}
