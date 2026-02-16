import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { redirect } from 'next/navigation';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { CafeSwitcher } from '@/components/CafeSwitcher';
import { Breadcrumbs } from '@/components/Breadcrumbs';
import { FinancialControlTowerView } from '@/components/FinancialControlTowerView';
import {
  getOwnerFinancialControlTower,
  listOwnerFinancialAnomalies,
} from '@/lib/supabase/queries/financial-control';

type OwnerCafe = {
  id: string;
  name: string | null;
};

function resolveRangeDays(value?: string): number {
  const parsed = Number(value || '30');
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

export default async function CafeFinancesPage({
  params,
  searchParams,
}: {
  params: Promise<{ cafeId: string }>;
  searchParams: Promise<{ days?: string; cafe?: string }>;
}) {
  const { userId } = await getUserRole();
  const { cafeId } = await params;
  const query = await searchParams;

  if (!userId) {
    redirect('/login');
  }

  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc('get_owner_cafes');
  const ownerCafes = (cafes || []) as OwnerCafe[];

  const ownsCafe = ownerCafes.some((cafe) => cafe.id === cafeId);
  if (!ownsCafe) {
    redirect('/admin/owner/dashboard');
  }

  const { data: cafe } = await supabase
    .from('cafes')
    .select('*')
    .eq('id', cafeId)
    .single();

  if (!cafe) {
    redirect('/admin/owner/dashboard');
  }

  const days = resolveRangeDays(query.days);
  const range = rangeToIso(days);

  const [metricsResult, anomaliesResult] = await Promise.all([
    getOwnerFinancialControlTower({
      from: range.from,
      to: range.to,
      cafeId,
    }),
    listOwnerFinancialAnomalies({
      from: range.from,
      to: range.to,
      cafeId,
      limit: 30,
    }),
  ]);

  const error = metricsResult.error || anomaliesResult.error;

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="cafe" cafeId={cafeId} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          <Breadcrumbs
            items={[
              { label: 'Главная', href: '/admin/owner/dashboard' },
              { label: 'Мои кофейни', href: '/admin/owner/cafes' },
              { label: cafe?.name || 'Кофейня', href: `/admin/owner/cafe/${cafeId}/dashboard` },
              { label: 'Финансы' },
            ]}
          />
          <div className="mb-6 flex items-center justify-between">
            <h1 className="text-2xl font-bold text-zinc-900">
              Финансы - {cafe?.name}
            </h1>
            <CafeSwitcher currentCafeId={cafeId} cafes={ownerCafes} />
          </div>
          <FinancialControlTowerView
            title="Financial Control Tower"
            subtitle="Сверка финансов по выбранной кофейне"
            scopeBadge="Cafe scope"
            basePath={`/admin/owner/cafe/${cafeId}/finances`}
            walletsPath="/admin/owner/wallets"
            rangeDays={days}
            cafeFilter={cafeId}
            cafes={[{ id: cafeId, name: cafe?.name || null }]}
            metrics={metricsResult.data}
            anomalies={anomaliesResult.data || []}
            error={error}
            hideCafeFilter
            lockedCafeLabel={cafe?.name || null}
          />
        </div>
      </main>
    </div>
  );
}
