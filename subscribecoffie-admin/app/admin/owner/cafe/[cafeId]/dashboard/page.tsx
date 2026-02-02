import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { redirect } from 'next/navigation';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { CafeSwitcher } from '@/components/CafeSwitcher';
import { Breadcrumbs } from '@/components/Breadcrumbs';
import { CafeStatusBadge } from '@/components/CafeStatusBadge';
import { getOrderStats, listOrdersByCafe } from '@/lib/supabase/queries/orders';
import Link from 'next/link';

export default async function CafeDashboardPage({
  params,
}: {
  params: Promise<{ cafeId: string }>;
}) {
  const { userId } = await getUserRole();
  const { cafeId } = await params;

  if (!userId) {
    redirect('/login');
  }

  const supabase = await createServerClient();

  // Get all owner's cafes for the switcher
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  // Verify user owns this cafe
  const ownsCafe = cafes?.some((cafe: any) => cafe.id === cafeId);
  if (!ownsCafe) {
    redirect('/admin/owner/dashboard');
  }

  // Get current cafe details
  const { data: cafe } = await supabase
    .from('cafes')
    .select('*')
    .eq('id', cafeId)
    .single();

  if (!cafe) {
    redirect('/admin/owner/dashboard');
  }

  // Get order stats using our new function
  const { data: stats, error: statsError } = await getOrderStats(cafeId);

  // Get recent orders for display
  const { data: recentOrders } = await listOrdersByCafe(cafeId);
  const recentOrdersToShow = recentOrders?.slice(0, 5) || [];

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar
        currentContext="cafe"
        cafeId={cafeId}
        activeOrdersCount={stats?.activeOrders || 0}
      />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          {/* Breadcrumbs */}
          <Breadcrumbs
            items={[
              { label: 'Главная', href: '/admin/owner/dashboard' },
              { label: 'Мои кофейни', href: '/admin/owner/cafes' },
              { label: cafe.name },
            ]}
          />

          {/* Header with Cafe Switcher */}
          <div className="mb-6 flex items-center justify-between">
            <div>
              <div className="flex items-center gap-3">
                <h1 className="text-2xl font-bold text-zinc-900">{cafe.name}</h1>
                <CafeStatusBadge cafeId={cafeId} currentStatus={cafe.status} />
              </div>
              <p className="mt-1 text-sm text-zinc-600">{cafe.address}</p>
            </div>
            <CafeSwitcher currentCafeId={cafeId} cafes={cafes || []} />
          </div>

          {statsError && (
            <div className="mb-4 rounded border border-red-200 bg-red-50 p-4">
              <p className="text-sm text-red-700">Ошибка загрузки статистики: {statsError}</p>
            </div>
          )}

          {/* Stats Grid */}
          <div className="mb-8 grid grid-cols-1 gap-6 md:grid-cols-4">
            <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
              <div className="mb-2 flex items-center justify-between">
                <p className="text-sm font-medium text-zinc-600">
                  Активные заказы
                </p>
                <span className="text-2xl">📦</span>
              </div>
              <p className="text-3xl font-bold text-zinc-900">
                {stats?.activeOrders ?? 0}
              </p>
              <p className="mt-2 text-xs text-zinc-500">
                В работе, готовятся, готовы
              </p>
            </div>

            <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
              <div className="mb-2 flex items-center justify-between">
                <p className="text-sm font-medium text-zinc-600">
                  Заказов сегодня
                </p>
                <span className="text-2xl">📊</span>
              </div>
              <p className="text-3xl font-bold text-zinc-900">
                {stats?.ordersToday ?? 0}
              </p>
              <p className="mt-2 text-xs text-zinc-500">
                Всего за сегодня
              </p>
            </div>

            <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
              <div className="mb-2 flex items-center justify-between">
                <p className="text-sm font-medium text-zinc-600">
                  Выручка сегодня
                </p>
                <span className="text-2xl">💰</span>
              </div>
              <p className="text-3xl font-bold text-zinc-900">
                {stats?.revenueToday ?? 0} ₽
              </p>
              <p className="mt-2 text-xs text-zinc-500">
                В кредитах
              </p>
            </div>

            <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
              <div className="mb-2 flex items-center justify-between">
                <p className="text-sm font-medium text-zinc-600">Статус</p>
                <span className="text-2xl">✅</span>
              </div>
              <div className="mt-3">
                <CafeStatusBadge cafeId={cafeId} currentStatus={cafe.status} readonly />
              </div>
              <Link
                href={`/admin/owner/cafe/${cafeId}/publication`}
                className="mt-3 block text-xs text-blue-600 hover:text-blue-700"
              >
                Управление публикацией →
              </Link>
            </div>
          </div>

          {/* Recent Activity */}
          <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-zinc-900">
                Последние заказы
              </h2>
              <Link
                href={`/admin/owner/cafe/${cafeId}/orders`}
                className="text-sm text-blue-600 hover:text-blue-700"
              >
                Все заказы →
              </Link>
            </div>
            {recentOrdersToShow && recentOrdersToShow.length > 0 ? (
              <div className="space-y-3">
                {recentOrdersToShow.map((order) => (
                  <div
                    key={order.id}
                    className="flex items-center justify-between rounded-lg border border-zinc-100 p-4"
                  >
                    <div>
                      <p className="text-sm font-medium text-zinc-900">
                        {order.order_number || `#${order.id.slice(0, 8)}`}
                      </p>
                      <p className="text-xs text-zinc-600">
                        {new Date(order.created_at).toLocaleString('ru-RU', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })} • {order.customer_name || 'Гость'}
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="text-right">
                        <p className="text-sm font-medium text-zinc-900">
                          {order.total_credits} ₽
                        </p>
                        <p className="text-xs text-zinc-600">
                          {order.order_items?.length ?? 0} поз.
                        </p>
                      </div>
                      <OrderStatusBadge status={order.status} />
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-center text-sm text-zinc-600">
                Заказов пока нет
              </p>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}

function OrderStatusBadge({ status }: { status: string }) {
  const colorMap: Record<string, string> = {
    created: "bg-blue-100 text-blue-700",
    accepted: "bg-yellow-100 text-yellow-700",
    in_progress: "bg-orange-100 text-orange-700",
    preparing: "bg-orange-100 text-orange-700",
    ready: "bg-green-100 text-green-700",
    issued: "bg-gray-100 text-gray-700",
    canceled: "bg-red-100 text-red-700",
  };

  const labelMap: Record<string, string> = {
    created: "Создан",
    accepted: "Принят",
    in_progress: "В работе",
    preparing: "Готовится",
    ready: "Готов",
    issued: "Выдан",
    canceled: "Отменен",
  };

  return (
    <span className={`inline-block rounded-full px-2.5 py-1 text-xs font-medium ${colorMap[status] || "bg-gray-100 text-gray-700"}`}>
      {labelMap[status] || status}
    </span>
  );
}
