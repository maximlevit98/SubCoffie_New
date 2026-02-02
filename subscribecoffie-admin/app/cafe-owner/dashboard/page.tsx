import Link from "next/link";
import { createServerClient } from "../../../lib/supabase/server";
import { getUserRole } from "../../../lib/supabase/roles";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string; period?: string }>;
};

export default async function CafeOwnerDashboardPage({
  searchParams,
}: PageProps) {
  const params = await searchParams;
  const cafeId = params?.cafe_id;
  const period = params?.period || "week";

  const { userId } = await getUserRole();
  const supabase = await createServerClient();

  // Get owner's cafes
  const { data: cafes, error: cafesError } = await supabase.rpc(
    "get_owner_cafes"
  );

  if (cafesError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Dashboard</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки данных: {cafesError.message}
        </p>
      </section>
    );
  }

  if (!cafes || cafes.length === 0) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Dashboard</h2>
        <div className="rounded-lg border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <div className="mb-4 text-6xl">☕</div>
          <h3 className="mb-2 text-lg font-semibold">У вас пока нет кафе</h3>
          <p className="mb-4 text-sm text-zinc-600">
            Обратитесь к администратору для добавления вашего кафе в систему
          </p>
        </div>
      </section>
    );
  }

  // Use first cafe if no cafe selected
  const selectedCafeId = cafeId || cafes[0].id;

  // Fetch dashboard metrics
  const { data: metrics, error: metricsError } = await supabase.rpc(
    "get_cafe_owner_dashboard_metrics",
    {
      cafe_id_param: selectedCafeId,
      period_param: period,
    }
  );

  const { data: topItems } = await supabase.rpc("get_cafe_owner_top_items", {
    cafe_id_param: selectedCafeId,
    limit_param: 5,
    days_param: period === "today" ? 1 : period === "week" ? 7 : 30,
  });

  const { data: hourlyStats } = await supabase.rpc(
    "get_cafe_owner_hourly_stats",
    {
      cafe_id_param: selectedCafeId,
      days_param: 7,
    }
  );

  const { data: customerRetention } = await supabase.rpc(
    "get_cafe_owner_customer_retention",
    {
      cafe_id_param: selectedCafeId,
      days_param: 30,
    }
  );

  const selectedCafe = cafes.find((c: any) => c.id === selectedCafeId);

  if (metricsError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Dashboard</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки метрик: {metricsError.message}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      {/* Header with Cafe & Period Selector */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Dashboard</h2>
          <p className="mt-1 text-sm text-zinc-500">
            {selectedCafe?.name} · {selectedCafe?.address}
          </p>
        </div>
        <div className="flex gap-3">
          <select
            className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={selectedCafeId}
            onChange={(e) => {
              const value = e.target.value;
              window.location.href = `/cafe-owner/dashboard?cafe_id=${value}&period=${period}`;
            }}
          >
            {cafes.map((cafe: any) => (
              <option key={cafe.id} value={cafe.id}>
                {cafe.name}
              </option>
            ))}
          </select>
          <select
            className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={period}
            onChange={(e) => {
              const value = e.target.value;
              window.location.href = `/cafe-owner/dashboard?cafe_id=${selectedCafeId}&period=${value}`;
            }}
          >
            <option value="today">Сегодня</option>
            <option value="week">Эта неделя</option>
            <option value="month">Этот месяц</option>
            <option value="all">Все время</option>
          </select>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <MetricCard
          title="Заказов"
          value={metrics?.orders?.total || 0}
          subtitle={`Завершено: ${metrics?.orders?.completed || 0}`}
          icon="📦"
          color="blue"
        />
        <MetricCard
          title="Выручка"
          value={`${Math.round(metrics?.revenue?.total || 0)} кр.`}
          subtitle={`Средний чек: ${Math.round(metrics?.revenue?.average_order || 0)} кр.`}
          icon="💰"
          color="green"
        />
        <MetricCard
          title="Эффективность"
          value={`${metrics?.performance?.completion_rate || 0}%`}
          subtitle={`${Math.round(metrics?.performance?.avg_preparation_minutes || 0)} мин подготовка`}
          icon="⚡"
          color="purple"
        />
      </div>

      {/* Customer Retention */}
      {customerRetention && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold">
            Клиенты (последние 30 дней)
          </h3>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
            <div className="rounded-lg bg-blue-50 p-4">
              <p className="text-sm text-zinc-600">Всего клиентов</p>
              <p className="mt-2 text-2xl font-bold text-blue-700">
                {customerRetention.total_customers || 0}
              </p>
            </div>
            <div className="rounded-lg bg-green-50 p-4">
              <p className="text-sm text-zinc-600">Возвращаются</p>
              <p className="mt-2 text-2xl font-bold text-green-700">
                {customerRetention.returning_customers || 0}
              </p>
            </div>
            <div className="rounded-lg bg-purple-50 p-4">
              <p className="text-sm text-zinc-600">Retention Rate</p>
              <p className="mt-2 text-2xl font-bold text-purple-700">
                {customerRetention.retention_rate || 0}%
              </p>
            </div>
            <div className="rounded-lg bg-orange-50 p-4">
              <p className="text-sm text-zinc-600">Заказов на клиента</p>
              <p className="mt-2 text-2xl font-bold text-orange-700">
                {customerRetention.avg_orders_per_customer || 0}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Peak Hours Chart */}
      {hourlyStats && hourlyStats.length > 0 && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold">
            Пиковые часы (последние 7 дней)
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

      {/* Top Menu Items */}
      {topItems && topItems.length > 0 && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-lg font-semibold">Топ-5 позиций меню</h3>
            <Link
              href={`/cafe-owner/analytics?cafe_id=${selectedCafeId}`}
              className="text-sm text-blue-600 hover:text-blue-700"
            >
              Подробная аналитика →
            </Link>
          </div>
          <div className="space-y-3">
            {topItems.map((item: any, idx: number) => (
              <div
                key={item.item_id}
                className="flex items-center gap-4 rounded-lg bg-zinc-50 p-3"
              >
                <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-zinc-200 text-sm font-semibold">
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
            ))}
          </div>
        </div>
      )}

      {/* Quick Actions */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <QuickActionCard
          href={`/cafe-owner/orders?cafe_id=${selectedCafeId}`}
          title="Управление заказами"
          description="Просмотр и обработка заказов"
          icon="📦"
        />
        <QuickActionCard
          href={`/cafe-owner/menu?cafe_id=${selectedCafeId}`}
          title="Редактировать меню"
          description="Добавление и изменение позиций"
          icon="📋"
        />
        <QuickActionCard
          href={`/cafe-owner/stop-list?cafe_id=${selectedCafeId}`}
          title="Стоп-лист"
          description="Управление доступностью позиций"
          icon="🚫"
        />
      </div>

      {/* Export Button */}
      <div className="flex justify-end">
        <button className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50">
          📥 Экспорт отчета
        </button>
      </div>
    </section>
  );
}

function MetricCard({
  title,
  value,
  subtitle,
  icon,
  color,
}: {
  title: string;
  value: string | number;
  subtitle: string;
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
      <div className="flex items-start gap-3">
        <div className="text-3xl">{icon}</div>
        <div className="flex-1">
          <p className="text-sm text-zinc-600">{title}</p>
          <p className="mt-1 text-2xl font-bold">{value}</p>
          <p className="mt-1 text-xs text-zinc-500">{subtitle}</p>
        </div>
      </div>
    </div>
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
            <div className="w-16 text-right text-sm text-zinc-600">
              {String(hour).padStart(2, "0")}:00
            </div>
            <div className="h-8 flex-1 overflow-hidden rounded-lg bg-zinc-100">
              <div
                className="flex h-full items-center justify-end bg-gradient-to-r from-blue-400 to-blue-600 px-2"
                style={{ width: `${percentage}%` }}
              >
                {orders > 0 && (
                  <span className="text-xs font-medium text-white">
                    {orders}
                  </span>
                )}
              </div>
            </div>
            <div className="w-20 text-right text-sm text-zinc-500">
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

  const sorted = [...data].sort(
    (a, b) => (b.orders_count || 0) - (a.orders_count || 0)
  );

  const top3 = sorted.slice(0, 3).filter((d) => d.orders_count > 0);

  return top3.map((d) => `${String(d.hour_of_day).padStart(2, "0")}:00`);
}

function QuickActionCard({
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
      className="rounded-lg border border-zinc-200 bg-white p-6 transition-shadow hover:shadow-md"
    >
      <div className="mb-3 text-3xl">{icon}</div>
      <h4 className="mb-1 font-semibold">{title}</h4>
      <p className="text-sm text-zinc-500">{description}</p>
    </Link>
  );
}
