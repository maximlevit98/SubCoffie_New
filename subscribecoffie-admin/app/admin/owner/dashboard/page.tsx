import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { getOwnerWalletsStats } from '@/lib/supabase/queries/owner-wallets';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { OwnerSidebar } from '@/components/OwnerSidebar';

type OwnerCafeStatus = 'draft' | 'moderation' | 'published' | 'paused' | 'rejected';

type OwnerCafe = {
  id: string;
  name: string;
  address: string;
  status: OwnerCafeStatus;
};

type TodayOrder = {
  subtotal_credits: number | null;
};

type DashboardOrder = {
  id: string;
  status: string;
  subtotal_credits: number | null;
  created_at: string;
  cafes: { name: string | null } | Array<{ name: string | null }> | null;
};

export default async function OwnerDashboardPage() {
  const { userId } = await getUserRole();

  if (!userId) {
    redirect('/login');
  }

  const supabase = await createServerClient();

  // Get owner's cafes
  const { data: cafes } = await supabase.rpc('get_owner_cafes');
  const ownerCafes = (cafes || []) as OwnerCafe[];

  const cafesCount = ownerCafes.length;
  const hasCafes = cafesCount > 0;

  // Get basic stats
  let todayOrders = 0;
  let todayRevenue = 0;
  let recentOrders: DashboardOrder[] = [];
  const { data: walletStats, error: walletStatsError } = await getOwnerWalletsStats();

  if (hasCafes) {
    const cafeIds = ownerCafes.map((cafe) => cafe.id);

    // Today's orders
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { data: ordersToday } = await supabase
      .from('orders')
      .select('subtotal_credits, paid_credits')
      .in('cafe_id', cafeIds)
      .gte('created_at', today.toISOString());

    const todayOrdersData = (ordersToday || []) as TodayOrder[];
    todayOrders = todayOrdersData.length;
    todayRevenue = todayOrdersData.reduce(
      (sum, order) => sum + (order.subtotal_credits || 0),
      0
    );

    // Recent orders
    const { data: recentOrdersData } = await supabase
      .from('orders')
      .select('id, cafe_id, status, subtotal_credits, created_at, cafes(name)')
      .in('cafe_id', cafeIds)
      .order('created_at', { ascending: false })
      .limit(10);

    recentOrders = (recentOrdersData || []) as DashboardOrder[];
  }

  const statusColors = {
    draft: 'bg-blue-100 text-blue-800',
    moderation: 'bg-yellow-100 text-yellow-800',
    published: 'bg-green-100 text-green-800',
    paused: 'bg-gray-100 text-gray-800',
    rejected: 'bg-red-100 text-red-800',
  };

  const statusLabels = {
    draft: 'Черновик',
    moderation: 'На модерации',
    published: 'Опубликовано',
    paused: 'Приостановлено',
    rejected: 'Отклонено',
  };

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="account" cafesCount={cafesCount} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          {/* Welcome Block */}
          <div className="mb-8">
            <h1 className="text-2xl font-bold text-zinc-900">
              Добро пожаловать!
            </h1>
            <p className="mt-1 text-sm text-zinc-600">
              Управляйте вашими кофейнями в одном месте
            </p>
          </div>

          {/* Stats Cards */}
          <div className="mb-8 grid grid-cols-1 gap-6 md:grid-cols-3">
            <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-zinc-600">
                    Всего кофеен
                  </p>
                  <p className="mt-2 text-3xl font-bold text-zinc-900">
                    {cafesCount}
                  </p>
                </div>
                <div className="flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
                  <span className="text-2xl">☕</span>
                </div>
              </div>
              <div className="mt-4">
                <Link
                  href="/admin/owner/cafes/new"
                  className="text-sm font-medium text-blue-600 hover:text-blue-700"
                >
                  + Создать новую
                </Link>
              </div>
            </div>

            <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-zinc-600">
                    Заказов сегодня
                  </p>
                  <p className="mt-2 text-3xl font-bold text-zinc-900">
                    {todayOrders}
                  </p>
                </div>
                <div className="flex h-12 w-12 items-center justify-center rounded-full bg-green-100">
                  <span className="text-2xl">📦</span>
                </div>
              </div>
            </div>

            <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-zinc-600">
                    Выручка сегодня
                  </p>
                  <p className="mt-2 text-3xl font-bold text-zinc-900">
                    {todayRevenue} кр.
                  </p>
                </div>
                <div className="flex h-12 w-12 items-center justify-center rounded-full bg-yellow-100">
                  <span className="text-2xl">💰</span>
                </div>
              </div>
            </div>
          </div>

          {/* Wallet Metrics */}
          <div className="mb-8">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-xl font-semibold text-zinc-900">
                Кошельки клиентов
              </h2>
              <Link
                href="/admin/owner/wallets"
                className="text-sm font-medium text-blue-600 hover:text-blue-700"
              >
                Открыть раздел →
              </Link>
            </div>

            {walletStatsError ? (
              <div className="rounded-lg border border-amber-200 bg-amber-50 p-4">
                <p className="text-sm text-amber-800">
                  Не удалось загрузить метрики кошельков: {walletStatsError}
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
                <MetricCard
                  label="Всего кошельков"
                  value={walletStats?.total_wallets || 0}
                  suffix=""
                  tone="neutral"
                />
                <MetricCard
                  label="Баланс кошельков"
                  value={walletStats?.total_balance_credits || 0}
                  suffix="кр."
                  tone="blue"
                />
                <MetricCard
                  label="Пополнено"
                  value={walletStats?.total_topup_credits || 0}
                  suffix="кр."
                  tone="green"
                />
                <MetricCard
                  label="Net поток"
                  value={walletStats?.net_wallet_change_credits || 0}
                  suffix="кр."
                  tone={(walletStats?.net_wallet_change_credits || 0) >= 0 ? 'green' : 'red'}
                />
              </div>
            )}
          </div>

          {/* Cafes Summary */}
          {hasCafes ? (
            <div className="mb-8">
              <div className="mb-4 flex items-center justify-between">
                <h2 className="text-xl font-semibold text-zinc-900">
                  Мои кофейни
                </h2>
                <Link
                  href="/admin/owner/cafes"
                  className="text-sm font-medium text-blue-600 hover:text-blue-700"
                >
                  Показать все →
                </Link>
              </div>
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
                {ownerCafes.map((cafe) => (
                  <div
                    key={cafe.id}
                    className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm"
                  >
                    <div className="mb-3 flex items-start justify-between">
                      <h3 className="font-semibold text-zinc-900">
                        {cafe.name}
                      </h3>
                      <span
                        className={`rounded-full px-2 py-1 text-xs font-medium ${statusColors[cafe.status as keyof typeof statusColors]}`}
                      >
                        {statusLabels[cafe.status as keyof typeof statusLabels]}
                      </span>
                    </div>
                    <p className="mb-4 text-sm text-zinc-600">{cafe.address}</p>
                    <div className="flex gap-2">
                      <Link
                        href={`/admin/owner/cafe/${cafe.id}/dashboard`}
                        className="flex-1 rounded-lg bg-blue-600 px-3 py-2 text-center text-sm font-medium text-white hover:bg-blue-700"
                      >
                        Открыть
                      </Link>
                      <Link
                        href={`/admin/owner/cafes/${cafe.id}`}
                        className="rounded-lg border border-zinc-200 px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
                      >
                        ⚙️
                      </Link>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="mb-8 rounded-lg border border-dashed border-zinc-300 bg-white p-12 text-center">
              <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-zinc-100">
                <span className="text-4xl">☕</span>
              </div>
              <h3 className="mb-2 text-lg font-semibold text-zinc-900">
                У вас пока нет кофеен
              </h3>
              <p className="mb-6 text-sm text-zinc-600">
                Создайте свою первую кофейню, чтобы начать принимать заказы
              </p>
              <Link
                href="/admin/owner/cafes/new"
                className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-6 py-3 text-sm font-medium text-white hover:bg-blue-700"
              >
                <span>+ Создать кофейню</span>
              </Link>
            </div>
          )}

          {/* Recent Orders */}
          {recentOrders.length > 0 && (
            <div>
              <h2 className="mb-4 text-xl font-semibold text-zinc-900">
                Последние заказы
              </h2>
              <div className="overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm">
                <table className="min-w-full divide-y divide-zinc-200">
                  <thead className="bg-zinc-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                        Номер
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                        Кофейня
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                        Статус
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                        Сумма
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                        Дата
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-200 bg-white">
                    {recentOrders.map((order) => (
                      <tr key={order.id} className="hover:bg-zinc-50">
                        <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-zinc-900">
                          #{order.id.slice(0, 8)}
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm text-zinc-600">
                          {Array.isArray(order.cafes)
                            ? order.cafes[0]?.name || 'N/A'
                            : order.cafes?.name || 'N/A'}
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm">
                          <span className="rounded-full bg-blue-100 px-2 py-1 text-xs font-medium text-blue-800">
                            {order.status}
                          </span>
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm text-zinc-900">
                          {order.subtotal_credits} кр.
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm text-zinc-600">
                          {new Date(order.created_at).toLocaleDateString(
                            'ru-RU'
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

function MetricCard({
  label,
  value,
  suffix,
  tone,
}: {
  label: string;
  value: number;
  suffix: string;
  tone: 'neutral' | 'blue' | 'green' | 'red';
}) {
  const toneStyles = {
    neutral: 'border-zinc-200 bg-white text-zinc-900',
    blue: 'border-blue-200 bg-blue-50 text-blue-900',
    green: 'border-emerald-200 bg-emerald-50 text-emerald-900',
    red: 'border-red-200 bg-red-50 text-red-900',
  };

  return (
    <div className={`rounded-lg border p-4 ${toneStyles[tone]}`}>
      <p className="text-xs font-medium text-zinc-500">{label}</p>
      <p className="mt-2 text-2xl font-bold">
        {value.toLocaleString('ru-RU')} {suffix}
      </p>
    </div>
  );
}
