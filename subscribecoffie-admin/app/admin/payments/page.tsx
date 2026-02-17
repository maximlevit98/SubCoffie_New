import { FinancialControlTowerView } from "@/components/FinancialControlTowerView";
import {
  getAdminFinancialControlTower,
  listAdminFinancialAnomalies,
  listCafesForFinancialFilters,
} from "@/lib/supabase/queries/financial-control";
import { requireAdmin } from "@/lib/supabase/roles";

type PaymentsPageProps = {
  searchParams: Promise<{
    days?: string;
    cafe?: string;
  }>;
};

function resolveRangeDays(value?: string): number {
  const parsed = Number(value || "30");
  if (!Number.isFinite(parsed)) return 30;
  if (![1, 7, 30, 90].includes(parsed)) return 30;
  return parsed;
}

function rangeToIso(days: number): { from: string; to: string } {
  const to = new Date();
  const from = new Date(to);
  from.setDate(to.getDate() - days);
  return {
    from: from.toISOString(),
    to: to.toISOString(),
  };
}

export default async function PaymentsPage({ searchParams }: PaymentsPageProps) {
  await requireAdmin();

  const params = await searchParams;
  const days = resolveRangeDays(params.days);
  const cafeId = params.cafe || "";
  const range = rangeToIso(days);

  const [metricsResult, anomaliesResult, cafesResult] = await Promise.all([
    getAdminFinancialControlTower({
      from: range.from,
      to: range.to,
      cafeId: cafeId || undefined,
    }),
    listAdminFinancialAnomalies({
      from: range.from,
      to: range.to,
      cafeId: cafeId || undefined,
      limit: 30,
    }),
    listCafesForFinancialFilters("admin"),
  ]);

  const error = metricsResult.error || anomaliesResult.error || cafesResult.error;

  return (
    <FinancialControlTowerView
      title="Financial Control Tower"
      subtitle="Сверка платежей, кошельков и заказов в едином контуре администратора"
      scopeBadge="Admin scope"
      basePath="/admin/payments"
      walletsPath="/admin/wallets"
      rangeDays={days}
      cafeFilter={cafeId}
      cafes={cafesResult.data || []}
      metrics={metricsResult.data}
      anomalies={anomaliesResult.data || []}
      error={error}
    />
  );
}
