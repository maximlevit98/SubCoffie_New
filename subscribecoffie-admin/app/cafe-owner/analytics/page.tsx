import { createServerClient } from "../../../lib/supabase/server";
import { getUserRole } from "../../../lib/supabase/roles";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string; period?: string }>;
};

export default async function CafeOwnerAnalyticsPage({
  searchParams,
}: PageProps) {
  const params = await searchParams;
  const cafeId = params?.cafe_id;
  const period = params?.period || "30";

  const { userId } = await getUserRole();
  const supabase = await createServerClient();

  // Get owner's cafes
  const { data: cafes, error: cafesError } = await supabase.rpc(
    "get_owner_cafes"
  );

  if (cafesError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Аналитика</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки данных: {cafesError.message}
        </p>
      </section>
    );
  }

  if (!cafes || cafes.length === 0) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Аналитика</h2>
        <div className="rounded-lg border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <div className="mb-4 text-6xl">☕</div>
          <h3 className="mb-2 text-lg font-semibold">У вас пока нет кафе</h3>
          <p className="text-sm text-zinc-600">
            Обратитесь к администратору для добавления вашего кафе в систему
          </p>
        </div>
      </section>
    );
  }

  // Use first cafe if no cafe selected
  const selectedCafeId = cafeId || cafes[0].id;

  // Fetch analytics data
  const { data: topItems } = await supabase.rpc("get_cafe_owner_top_items", {
    cafe_id_param: selectedCafeId,
    limit_param: 20,
    days_param: parseInt(period),
  });

  const { data: hourlyStats } = await supabase.rpc(
    "get_cafe_owner_hourly_stats",
    {
      cafe_id_param: selectedCafeId,
      days_param: parseInt(period),
    }
  );

  const { data: customerRetention } = await supabase.rpc(
    "get_cafe_owner_customer_retention",
    {
      cafe_id_param: selectedCafeId,
      days_param: parseInt(period),
    }
  );

  const selectedCafe = cafes.find((c: any) => c.id === selectedCafeId);

  return (
    <section className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-semibold">📈 Подробная аналитика</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Детальная статистика работы вашего кафе
          </p>
          <p className="mt-1 text-sm text-zinc-600">
            {selectedCafe?.name} · {selectedCafe?.address}
          </p>
        </div>
        <div className="flex gap-3">
          <select
            className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={selectedCafeId}
            onChange={(e) => {
              const value = e.target.value;
              window.location.href = `/cafe-owner/analytics?cafe_id=${value}&period=${period}`;
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
              window.location.href = `/cafe-owner/analytics?cafe_id=${selectedCafeId}&period=${value}`;
            }}
          >
            <option value="7">7 дней</option>
            <option value="30">30 дней</option>
            <option value="90">90 дней</option>
            <option value="365">1 год</option>
          </select>
        </div>
      </div>

      {/* Customer Retention */}
      {customerRetention && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold">👥 Клиенты и лояльность</h3>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
            <div className="rounded-lg bg-blue-50 p-4">
              <p className="text-sm text-zinc-600">Всего клиентов</p>
              <p className="mt-2 text-3xl font-bold text-blue-700">
                {customerRetention.total_customers || 0}
              </p>
            </div>
            <div className="rounded-lg bg-green-50 p-4">
              <p className="text-sm text-zinc-600">Возвращаются</p>
              <p className="mt-2 text-3xl font-bold text-green-700">
                {customerRetention.returning_customers || 0}
              </p>
            </div>
            <div className="rounded-lg bg-purple-50 p-4">
              <p className="text-sm text-zinc-600">Retention Rate</p>
              <p className="mt-2 text-3xl font-bold text-purple-700">
                {customerRetention.retention_rate || 0}%
              </p>
            </div>
            <div className="rounded-lg bg-orange-50 p-4">
              <p className="text-sm text-zinc-600">Заказов на клиента</p>
              <p className="mt-2 text-3xl font-bold text-orange-700">
                {customerRetention.avg_orders_per_customer || 0}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Peak Hours */}
      {hourlyStats && hourlyStats.length > 0 && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold">⏰ Распределение заказов по часам</h3>
          <HourlyChart data={hourlyStats} />
          <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-3">
            <div className="rounded-lg bg-zinc-50 p-4">
              <p className="text-sm text-zinc-600">Пиковые часы</p>
              <p className="mt-2 text-lg font-semibold">
                {findPeakHours(hourlyStats).join(", ")}
              </p>
            </div>
            <div className="rounded-lg bg-zinc-50 p-4">
              <p className="text-sm text-zinc-600">Всего заказов</p>
              <p className="mt-2 text-lg font-semibold">
                {hourlyStats.reduce(
                  (sum, h) => sum + (Number(h.orders_count) || 0),
                  0
                )}
              </p>
            </div>
            <div className="rounded-lg bg-zinc-50 p-4">
              <p className="text-sm text-zinc-600">Средний чек</p>
              <p className="mt-2 text-lg font-semibold">
                {Math.round(
                  hourlyStats.reduce(
                    (sum, h) => sum + (Number(h.avg_order_value) || 0),
                    0
                  ) / hourlyStats.length
                )}{" "}
                кр.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Top Items - Full List */}
      {topItems && topItems.length > 0 && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold">🏆 Топ позиций меню</h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-zinc-200 text-left text-zinc-600">
                <tr>
                  <th className="px-4 py-3 font-medium">#</th>
                  <th className="px-4 py-3 font-medium">Позиция</th>
                  <th className="px-4 py-3 font-medium">Категория</th>
                  <th className="px-4 py-3 text-right font-medium">
                    Продано (шт)
                  </th>
                  <th className="px-4 py-3 text-right font-medium">
                    Выручка (кр)
                  </th>
                  <th className="px-4 py-3 text-right font-medium">
                    Заказов
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {topItems.map((item: any, idx: number) => (
                  <tr key={item.item_id} className="text-zinc-700">
                    <td className="px-4 py-3">
                      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-zinc-100 text-sm font-semibold">
                        {idx + 1}
                      </div>
                    </td>
                    <td className="px-4 py-3 font-medium">{item.item_name}</td>
                    <td className="px-4 py-3 text-zinc-500">{item.category}</td>
                    <td className="px-4 py-3 text-right font-semibold">
                      {item.total_quantity}
                    </td>
                    <td className="px-4 py-3 text-right font-semibold">
                      {Math.round(item.total_revenue)}
                    </td>
                    <td className="px-4 py-3 text-right text-zinc-500">
                      {item.order_count}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Export Button */}
      <div className="flex justify-end gap-3">
        <button className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50">
          📥 Экспорт Excel
        </button>
        <button className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50">
          📄 Экспорт PDF
        </button>
      </div>
    </section>
  );
}

function HourlyChart({ data }: { data: any[] }) {
  const maxOrders = Math.max(...data.map((d) => Number(d.orders_count) || 0), 1);

  return (
    <div className="space-y-2">
      {data.map((hourData) => {
        const hour = hourData.hour_of_day;
        const orders = Number(hourData.orders_count) || 0;
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
              {Math.round(Number(hourData.total_revenue) || 0)} кр.
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
    (a, b) => (Number(b.orders_count) || 0) - (Number(a.orders_count) || 0)
  );

  const top3 = sorted
    .slice(0, 3)
    .filter((d) => (Number(d.orders_count) || 0) > 0);

  return top3.map((d) => `${String(d.hour_of_day).padStart(2, "0")}:00`);
}
