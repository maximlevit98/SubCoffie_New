import { redirect } from "next/navigation";

import { FinancialControlTowerView } from "@/components/FinancialControlTowerView";
import { OwnerSidebar } from "@/components/OwnerSidebar";
import {
  getOwnerFinancialControlTower,
  listCafesForFinancialFilters,
  listOwnerFinancialAnomalies,
} from "@/lib/supabase/queries/financial-control";
import { getUserRole } from "@/lib/supabase/roles";

type OwnerFinancesPageProps = {
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

export default async function FinancesPage({ searchParams }: OwnerFinancesPageProps) {
  const { role, userId } = await getUserRole();

  if (!userId) {
    redirect("/login");
  }

  if (role !== "owner" && role !== "admin") {
    redirect("/admin/dashboard");
  }

  const params = await searchParams;
  const days = resolveRangeDays(params.days);
  const cafeId = params.cafe || "";
  const range = rangeToIso(days);

  const [cafesResult, metricsResult, anomaliesResult] = await Promise.all([
    listCafesForFinancialFilters("owner"),
    getOwnerFinancialControlTower({
      from: range.from,
      to: range.to,
      cafeId: cafeId || undefined,
    }),
    listOwnerFinancialAnomalies({
      from: range.from,
      to: range.to,
      cafeId: cafeId || undefined,
      limit: 30,
    }),
  ]);

  const error = metricsResult.error || anomaliesResult.error || cafesResult.error;
  const cafes = cafesResult.data || [];

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="account" cafesCount={cafes.length} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          <FinancialControlTowerView
            title="Financial Control Tower"
            subtitle="Финансовый контроль по вашим кофейням: пополнения, списания, возвраты и сверка"
            scopeBadge="Owner scope"
            basePath="/admin/owner/finances"
            walletsPath="/admin/owner/wallets"
            rangeDays={days}
            cafeFilter={cafeId}
            cafes={cafes}
            metrics={metricsResult.data}
            anomalies={anomaliesResult.data || []}
            error={error}
          />
        </div>
      </main>
    </div>
  );
}
