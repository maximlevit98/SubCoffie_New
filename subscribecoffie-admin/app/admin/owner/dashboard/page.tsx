import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { OwnerSidebar } from '@/components/OwnerSidebar';

export default async function OwnerDashboardPage() {
  const { userId } = await getUserRole();

  if (!userId) {
    redirect('/login');
  }

  const supabase = await createServerClient();

  // Get owner's cafes
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  const cafesCount = cafes?.length || 0;
  const hasCafes = cafesCount > 0;

  // Get basic stats
  let todayOrders = 0;
  let todayRevenue = 0;
  let recentOrders: any[] = [];

  if (hasCafes) {
    const cafeIds = cafes.map((cafe: any) => cafe.id);

    // Today's orders
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { data: ordersToday } = await supabase
      .from('orders')
      .select('total_amount')
      .in('cafe_id', cafeIds)
      .gte('created_at', today.toISOString());

    todayOrders = ordersToday?.length || 0;
    todayRevenue = ordersToday?.reduce(
      (sum: number, order: any) => sum + (order.total_amount || 0),
      0
    ) || 0;

    // Recent orders
    const { data: recentOrdersData } = await supabase
      .from('orders')
      .select('*, cafes(name)')
      .in('cafe_id', cafeIds)
      .order('created_at', { ascending: false })
      .limit(10);

    recentOrders = recentOrdersData || [];
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
                    {todayRevenue} ₽
                  </p>
                </div>
                <div className="flex h-12 w-12 items-center justify-center rounded-full bg-yellow-100">
                  <span className="text-2xl">💰</span>
                </div>
              </div>
            </div>
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
                {cafes?.map((cafe: any) => (
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
                    {recentOrders.map((order: any) => (
                      <tr key={order.id} className="hover:bg-zinc-50">
                        <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-zinc-900">
                          #{order.id.slice(0, 8)}
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm text-zinc-600">
                          {order.cafes?.name || 'N/A'}
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm">
                          <span className="rounded-full bg-blue-100 px-2 py-1 text-xs font-medium text-blue-800">
                            {order.status}
                          </span>
                        </td>
                        <td className="whitespace-nowrap px-6 py-4 text-sm text-zinc-900">
                          {order.total_amount} ₽
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
