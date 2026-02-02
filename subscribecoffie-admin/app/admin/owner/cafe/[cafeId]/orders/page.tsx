import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { redirect } from 'next/navigation';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { CafeSwitcher } from '@/components/CafeSwitcher';
import { Breadcrumbs } from '@/components/Breadcrumbs';
import { listOrdersByCafe } from '@/lib/supabase/queries/orders';

export default async function CafeOrdersPage({
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
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  const ownsCafe = cafes?.some((cafe: any) => cafe.id === cafeId);
  if (!ownsCafe) {
    redirect('/admin/owner/dashboard');
  }

  const { data: cafe } = await supabase
    .from('cafes')
    .select('*')
    .eq('id', cafeId)
    .single();

  // Get orders for this cafe
  const { data: orders, error: ordersError } = await listOrdersByCafe(cafeId);

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="cafe" cafeId={cafeId} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          {/* Breadcrumbs */}
          <Breadcrumbs
            items={[
              { label: 'Главная', href: '/admin/owner/dashboard' },
              { label: 'Мои кофейни', href: '/admin/owner/cafes' },
              {
                label: cafe?.name || 'Кофейня',
                href: `/admin/owner/cafe/${cafeId}/dashboard`,
              },
              { label: 'Заказы' },
            ]}
          />

          <div className="mb-6 flex items-center justify-between">
            <h1 className="text-2xl font-bold text-zinc-900">
              Заказы - {cafe?.name}
            </h1>
            <CafeSwitcher currentCafeId={cafeId} cafes={cafes || []} />
          </div>

          {ordersError && (
            <div className="mb-4 rounded border border-red-200 bg-red-50 p-4">
              <p className="text-sm text-red-700">Ошибка загрузки заказов: {ordersError}</p>
            </div>
          )}

          <section className="space-y-6">
            <div className="flex items-center justify-between">
              <p className="text-sm text-zinc-600">Всего: {orders?.length ?? 0}</p>
            </div>

            <div className="overflow-x-auto rounded-lg border border-zinc-200 bg-white">
              <table className="min-w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50">
                  <tr>
                    <th className="px-4 py-3 font-medium text-zinc-700">Номер</th>
                    <th className="px-4 py-3 font-medium text-zinc-700">Время</th>
                    <th className="px-4 py-3 font-medium text-zinc-700">Клиент</th>
                    <th className="px-4 py-3 font-medium text-zinc-700">Позиции</th>
                    <th className="px-4 py-3 font-medium text-zinc-700">Сумма</th>
                    <th className="px-4 py-3 font-medium text-zinc-700">Оплата</th>
                    <th className="px-4 py-3 font-medium text-zinc-700">Статус</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100">
                  {orders && orders.length > 0 ? (
                    orders.map((order) => (
                      <tr key={order.id} className="text-zinc-700 hover:bg-zinc-50">
                        <td className="px-4 py-3 font-mono text-xs">
                          {order.order_number || order.id.slice(0, 8)}
                        </td>
                        <td className="px-4 py-3 text-xs">
                          {new Date(order.created_at).toLocaleString('ru-RU', {
                            year: 'numeric',
                            month: '2-digit',
                            day: '2-digit',
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </td>
                        <td className="px-4 py-3">
                          <div className="text-sm">{order.customer_name || 'Гость'}</div>
                          <div className="text-xs text-zinc-500">{order.customer_phone}</div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="text-xs">
                            {order.order_items && order.order_items.length > 0 ? (
                              <div className="space-y-1">
                                {order.order_items.map((item) => (
                                  <div key={item.id}>
                                    {item.quantity}x {item.item_name}
                                  </div>
                                ))}
                              </div>
                            ) : (
                              <span className="text-zinc-400">—</span>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3 font-semibold">
                          {order.total_credits} ₽
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex flex-col gap-1">
                            <span className="text-xs">{order.payment_method || '—'}</span>
                            <PaymentStatusBadge status={order.payment_status} />
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <StatusBadge status={order.status} />
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={7} className="px-4 py-8 text-center text-sm text-zinc-500">
                        Заказов пока нет
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const colorMap: Record<string, string> = {
    created: "bg-blue-100 text-blue-800",
    accepted: "bg-yellow-100 text-yellow-800",
    in_progress: "bg-orange-100 text-orange-800",
    preparing: "bg-orange-100 text-orange-800",
    ready: "bg-green-100 text-green-800",
    issued: "bg-gray-100 text-gray-800",
    canceled: "bg-red-100 text-red-800",
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
    <span className={`inline-block rounded px-2 py-1 text-xs font-medium ${colorMap[status] || "bg-gray-100 text-gray-800"}`}>
      {labelMap[status] || status}
    </span>
  );
}

function PaymentStatusBadge({ status }: { status: string }) {
  const colorMap: Record<string, string> = {
    paid: "bg-green-100 text-green-800",
    pending: "bg-yellow-100 text-yellow-800",
    failed: "bg-red-100 text-red-800",
    refunded: "bg-gray-100 text-gray-800",
  };

  const labelMap: Record<string, string> = {
    paid: "Оплачен",
    pending: "Ожидает",
    failed: "Ошибка",
    refunded: "Возврат",
  };

  return (
    <span className={`inline-block rounded px-1.5 py-0.5 text-xs ${colorMap[status] || "bg-gray-100 text-gray-800"}`}>
      {labelMap[status] || status}
    </span>
  );
}
