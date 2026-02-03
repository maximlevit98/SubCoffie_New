import Link from "next/link";
import { Suspense } from "react";
import { redirect } from "next/navigation";

import {
  getDashboardMetrics,
  getRevenueByDay,
  getTopMenuItems,
  getHourlyOrdersStats,
  getCafeConversionStats,
} from "../../../lib/supabase/queries/analytics";
import { listCafes } from "../../../lib/supabase/queries/cafes";
import { CafeSelectorClient } from "./CafeSelectorClient";
import LegacyAdminLayout from "@/components/LegacyAdminLayout";
import { getUserRole } from "@/lib/supabase/roles";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string }>;
};

export default async function DashboardPage({ searchParams }: PageProps) {
  // ADMIN-ONLY GUARD
  const { role, userId } = await getUserRole();
  
  if (!userId) {
    redirect('/login');
  }
  
  // Strict: only admin can access admin dashboard
  if (role !== 'admin') {
    redirect('/admin/owner/dashboard');
  }
  
  const params = await searchParams;
  const cafeId = params?.cafe_id;

  let metrics: any = null;
  let revenueData: any[] = [];
  let topItems: any[] = [];
  let hourlyStats: any[] = [];
  let conversionStats: any = null;
  let cafes: any[] = [];
  let error: string | null = null;

  try {
    // Fetch cafes for the selector
    const cafesResult = await listCafes();
    cafes = cafesResult.data || [];

    // Fetch dashboard data
    const results = await Promise.all([
      getDashboardMetrics(cafeId),
      getRevenueByDay(cafeId, 7),
      getTopMenuItems(cafeId, 5),
      cafeId ? getHourlyOrdersStats(cafeId) : Promise.resolve({ data: [] }),
      cafeId
        ? getCafeConversionStats(cafeId)
        : Promise.resolve({ data: null }),
    ]);

    metrics = results[0].data;
    revenueData = results[1].data || [];
    topItems = results[2].data || [];
    hourlyStats = results[3].data || [];
    conversionStats = results[4].data;
  } catch (e: any) {
    error = e.message;
  }

  if (error) {
    return (
      <LegacyAdminLayout>
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Dashboard</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить dashboard: {error}
        </p>
      </section>
      </LegacyAdminLayout>
    );
  }

  const today = metrics?.today || {};
  const thisWeek = metrics?.this_week || {};
  const thisMonth = metrics?.this_month || {};
  const allTime = metrics?.all_time || {};

  return (
    <LegacyAdminLayout>
    <section className="space-y-6">
      {/* Header with Cafe Selector */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Dashboard</h2>
          <p className="text-sm text-zinc-500 mt-1">
            Обзор ключевых метрик и статистики
          </p>
        </div>
        <CafeSelectorClient cafes={cafes} currentCafeId={cafeId} />
      </div>

      {/* Metrics Grid */}
      <div>
        <h3 className="text-lg font-semibold mb-3">Сегодня</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <MetricCard
            title="Заказов"
            value={today.orders || 0}
            icon="📦"
            color="blue"
          />
          <MetricCard
            title="Выручка"
            value={`${Math.round(today.revenue || 0)} кр.`}
            icon="💰"
            color="green"
          />
        </div>
      </div>

      <div>
        <h3 className="text-lg font-semibold mb-3">Эта неделя</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <MetricCard
            title="Заказов"
            value={thisWeek.orders || 0}
            icon="📦"
            color="blue"
          />
          <MetricCard
            title="Выручка"
            value={`${Math.round(thisWeek.revenue || 0)} кр.`}
            icon="💰"
            color="green"
          />
        </div>
      </div>

      <div>
        <h3 className="text-lg font-semibold mb-3">Этот месяц</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <MetricCard
            title="Заказов"
            value={thisMonth.orders || 0}
            icon="📦"
            color="blue"
          />
          <MetricCard
            title="Выручка"
            value={`${Math.round(thisMonth.revenue || 0)} кр.`}
            icon="💰"
            color="green"
          />
          <MetricCard
            title="Средний чек"
            value={`${Math.round((thisMonth.revenue || 0) / (thisMonth.orders || 1))} кр.`}
            icon="📊"
            color="purple"
          />
        </div>
      </div>

      {/* Conversion Stats (only if cafe is selected) */}
      {cafeId && conversionStats && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="text-lg font-semibold mb-4">
            Конверсия и эффективность
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 rounded-lg bg-green-50 border border-green-200">
              <p className="text-sm text-zinc-600 mb-1">Успешных заказов</p>
              <p className="text-2xl font-bold text-green-700">
                {conversionStats.orders?.completed || 0}
              </p>
              <p className="text-xs text-zinc-500 mt-1">
                из {conversionStats.orders?.total || 0} всего
              </p>
            </div>
            <div className="p-4 rounded-lg bg-blue-50 border border-blue-200">
              <p className="text-sm text-zinc-600 mb-1">Процент завершения</p>
              <p className="text-2xl font-bold text-blue-700">
                {conversionStats.conversion?.completion_rate || 0}%
              </p>
              <p className="text-xs text-zinc-500 mt-1">конверсия</p>
            </div>
            <div className="p-4 rounded-lg bg-purple-50 border border-purple-200">
              <p className="text-sm text-zinc-600 mb-1">
                Среднее время подготовки
              </p>
              <p className="text-2xl font-bold text-purple-700">
                {Math.round(
                  conversionStats.performance?.avg_preparation_minutes || 0
                )}{" "}
                мин
              </p>
              <p className="text-xs text-zinc-500 mt-1">
                от оплаты до готовности
              </p>
            </div>
          </div>
          {conversionStats.orders?.cancelled > 0 && (
            <div className="mt-4 p-3 rounded-lg bg-red-50 border border-red-200">
              <p className="text-sm text-red-700">
                ⚠️ Отменено заказов: {conversionStats.orders.cancelled} (
                {conversionStats.conversion?.cancellation_rate || 0}%)
              </p>
            </div>
          )}
        </div>
      )}

      {/* Peak Hours (only if cafe is selected) */}
      {cafeId && hourlyStats && hourlyStats.length > 0 && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="text-lg font-semibold mb-4">
            Пиковые часы заказов (последние 7 дней)
          </h3>
          <HourlyChart data={hourlyStats} />
          <div className="mt-4 text-sm text-zinc-600">
            <p>
              💡 <strong>Пиковое время:</strong>{" "}
              {findPeakHours(hourlyStats).join(", ")}
            </p>
          </div>
        </div>
      )}

      {/* Revenue Chart */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">
          Выручка за последние 7 дней
        </h3>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="border-b border-zinc-200 text-zinc-600">
              <tr>
                <th className="py-3 px-4 text-left font-medium">Дата</th>
                <th className="py-3 px-4 text-right font-medium">Заказов</th>
                <th className="py-3 px-4 text-right font-medium">Выручка</th>
                <th className="py-3 px-4 text-right font-medium">
                  Средний чек
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {revenueData && revenueData.length > 0 ? (
                revenueData.map((row: any) => (
                  <tr key={row.date} className="text-zinc-700">
                    <td className="py-3 px-4">
                      {new Date(row.date).toLocaleDateString("ru-RU")}
                    </td>
                    <td className="py-3 px-4 text-right">{row.orders_count}</td>
                    <td className="py-3 px-4 text-right font-medium">
                      {Math.round(row.revenue)} кр.
                    </td>
                    <td className="py-3 px-4 text-right text-zinc-500">
                      {Math.round(row.avg_order_value)} кр.
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td
                    className="py-6 px-4 text-center text-zinc-500"
                    colSpan={4}
                  >
                    Нет данных
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Top Menu Items */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">Топ-5 позиций меню</h3>
        <div className="space-y-3">
          {topItems && topItems.length > 0 ? (
            topItems.map((item: any, idx: number) => (
              <div
                key={item.item_id}
                className="flex items-center gap-4 p-3 rounded-lg bg-zinc-50"
              >
                <div className="flex-shrink-0 w-8 h-8 rounded-full bg-zinc-200 flex items-center justify-center font-semibold text-sm">
                  {idx + 1}
                </div>
                <div className="flex-1">
                  <p className="font-medium">{item.item_name}</p>
                  <p className="text-xs text-zinc-500">{item.category}</p>
                </div>
                <div className="text-right">
                  <p className="font-semibold">{item.total_quantity} шт.</p>
                  <p className="text-xs text-zinc-500">
                    {Math.round(item.total_revenue)} кр.
                  </p>
                </div>
              </div>
            ))
          ) : (
            <p className="text-sm text-zinc-500">Нет данных</p>
          )}
        </div>
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <QuickLink
          href="/admin/orders"
          title="Заказы"
          description="Управление заказами"
          icon="📦"
        />
        <QuickLink
          href="/admin/wallets"
          title="Кошельки"
          description="Управление балансами"
          icon="💳"
        />
        <QuickLink
          href="/admin/cafes"
          title="Кафе"
          description="Управление кафе и меню"
          icon="☕"
        />
        <QuickLink
          href="/admin/owner-invitations"
          title="Owner Invitations"
          description="Пригласить владельцев"
          icon="👤"
        />
      </div>
    </section>
  </LegacyAdminLayout>
  );
}


function HourlyChart({ data }: { data: any[] }) {
  const maxOrders = Math.max(...data.map((d) => d.orders_count || 0), 1);

  return (
    <div className="space-y-2">
      {data.map((hourData) => {
        const hour = hourData.hour_of_day;
        const orders = hourData.orders_count || 0;
        const percentage = (orders / maxOrders) * 100;

        return (
          <div key={hour} className="flex items-center gap-3">
            <div className="w-16 text-sm text-zinc-600 text-right">
              {String(hour).padStart(2, "0")}:00
            </div>
            <div className="flex-1 h-8 bg-zinc-100 rounded-lg overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-blue-400 to-blue-600 flex items-center justify-end px-2"
                style={{ width: `${percentage}%` }}
              >
                {orders > 0 && (
                  <span className="text-xs text-white font-medium">
                    {orders}
                  </span>
                )}
              </div>
            </div>
            <div className="w-20 text-sm text-zinc-500 text-right">
              {Math.round(hourData.total_revenue || 0)} кр.
            </div>
          </div>
        );
      })}
    </div>
  );
}

function findPeakHours(data: any[]): string[] {
  if (!data || data.length === 0) return ["нет данных"];

  // Sort by orders count descending
  const sorted = [...data].sort(
    (a, b) => (b.orders_count || 0) - (a.orders_count || 0)
  );

  // Take top 3
  const top3 = sorted.slice(0, 3).filter((d) => d.orders_count > 0);

  return top3.map((d) => `${String(d.hour_of_day).padStart(2, "0")}:00`);
}

function MetricCard({
  title,
  value,
  icon,
  color,
}: {
  title: string;
  value: string | number;
  icon: string;
  color: "blue" | "green" | "purple";
}) {
  const colorClasses = {
    blue: "border-blue-200 bg-blue-50",
    green: "border-green-200 bg-green-50",
    purple: "border-purple-200 bg-purple-50",
  };

  return (
    <div className={`rounded-lg border ${colorClasses[color]} p-6`}>
      <div className="flex items-center gap-3">
        <div className="text-3xl">{icon}</div>
        <div>
          <p className="text-sm text-zinc-600">{title}</p>
          <p className="text-2xl font-bold mt-1">{value}</p>
        </div>
      </div>
    </div>
  );
}

function QuickLink({
  href,
  title,
  description,
  icon,
}: {
  href: string;
  title: string;
  description: string;
  icon: string;
}) {
  return (
    <Link
      href={href}
      className="rounded-lg border border-zinc-200 bg-white p-6 hover:shadow-md transition-shadow"
    >
      <div className="text-3xl mb-3">{icon}</div>
      <h4 className="font-semibold mb-1">{title}</h4>
      <p className="text-sm text-zinc-500">{description}</p>
    </Link>
  );
}
