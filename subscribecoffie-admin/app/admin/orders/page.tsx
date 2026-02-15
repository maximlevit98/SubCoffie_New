import Link from "next/link";

import { getOrders, getOrdersStats } from "./actions";
import { OrdersTable } from "./OrdersTable";

type OrdersPageProps = {
  searchParams: Promise<{
    status?: string;
    cafe?: string;
  }>;
};

export default async function OrdersPage({ searchParams }: OrdersPageProps) {
  const params = await searchParams;
  let orders: unknown[] = [];
  let stats: {
    by_status?: Record<string, number>;
    total_orders?: number;
    total_revenue?: number;
    avg_order_value?: number;
  } | null = null;
  let error: string | null = null;

  try {
    [orders, stats] = await Promise.all([
      getOrders({
        status: params?.status,
        cafeId: params?.cafe,
      }),
      getOrdersStats({
        cafeId: params?.cafe,
      }),
    ]);
  } catch (e: unknown) {
    error = e instanceof Error ? e.message : "Unknown error";
  }

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Заказы</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить заказы: {error}
        </p>
      </section>
    );
  }

  const statusCounts = stats?.by_status || {};

  return (
    <section className="space-y-6">
      {/* Header with Stats */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-semibold">Заказы</h2>
          <span className="text-sm text-emerald-600">Supabase: OK</span>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div className="rounded-lg border border-zinc-200 bg-white p-4">
            <p className="text-sm text-zinc-500">Всего заказов</p>
            <p className="text-2xl font-semibold mt-1">
              {stats?.total_orders || 0}
            </p>
          </div>
          <div className="rounded-lg border border-zinc-200 bg-white p-4">
            <p className="text-sm text-zinc-500">Общая выручка</p>
            <p className="text-2xl font-semibold mt-1">
              {Math.round(stats?.total_revenue || 0)} кр.
            </p>
          </div>
          <div className="rounded-lg border border-zinc-200 bg-white p-4">
            <p className="text-sm text-zinc-500">Средний чек</p>
            <p className="text-2xl font-semibold mt-1">
              {Math.round(stats?.avg_order_value || 0)} кр.
            </p>
          </div>
          <div className="rounded-lg border border-zinc-200 bg-white p-4">
            <p className="text-sm text-zinc-500">Статусы</p>
            <div className="flex flex-wrap gap-1 mt-2">
              {Object.entries(statusCounts).map(([status, count]) => (
                <span
                  key={status}
                  className="inline-flex items-center text-xs px-2 py-1 rounded bg-zinc-100 text-zinc-700"
                >
                  {status}: {count as number}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-2">
        <Link
          href="/admin/orders"
          className={`px-3 py-1.5 rounded text-sm ${
            !params?.status
              ? "bg-zinc-900 text-white"
              : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
          }`}
        >
          Все
        </Link>
        {["created", "paid", "preparing", "ready", "issued", "cancelled"].map(
          (status) => (
            <Link
              key={status}
              href={`/admin/orders?status=${status}`}
              className={`px-3 py-1.5 rounded text-sm ${
                params?.status === status
                  ? "bg-zinc-900 text-white"
                  : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              }`}
            >
              {status}
            </Link>
          )
        )}
      </div>

      {/* Orders Table */}
      <OrdersTable orders={orders} />
    </section>
  );
}
