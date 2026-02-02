import { createServerClient } from "../../../lib/supabase/server";
import { getUserRole } from "../../../lib/supabase/roles";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string; status?: string }>;
};

export default async function CafeOwnerOrdersPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const cafeId = params?.cafe_id;
  const statusFilter = params?.status;

  const { userId } = await getUserRole();
  const supabase = await createServerClient();

  // Get owner's cafes
  const { data: cafes, error: cafesError } = await supabase.rpc(
    "get_owner_cafes"
  );

  if (cafesError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Заказы</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки данных: {cafesError.message}
        </p>
      </section>
    );
  }

  if (!cafes || cafes.length === 0) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Заказы</h2>
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

  // Fetch orders with user info
  let ordersQuery = supabase
    .from("orders")
    .select(
      `
      *,
      profiles:user_id (
        phone,
        full_name
      )
    `
    )
    .eq("cafe_id", selectedCafeId)
    .order("created_at", { ascending: false })
    .limit(100);

  if (statusFilter && statusFilter !== "all") {
    ordersQuery = ordersQuery.eq("status", statusFilter);
  }

  const { data: orders, error: ordersError } = await ordersQuery;

  const selectedCafe = cafes.find((c: any) => c.id === selectedCafeId);

  if (ordersError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Заказы</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки заказов: {ordersError.message}
        </p>
      </section>
    );
  }

  const statusLabels: { [key: string]: string } = {
    pending: "⏳ Ожидание",
    paid: "💳 Оплачено",
    preparing: "👨‍🍳 Готовится",
    ready: "✅ Готово",
    picked_up: "🎉 Выдано",
    cancelled: "❌ Отменено",
  };

  const statusColors: { [key: string]: string } = {
    pending: "bg-yellow-100 text-yellow-800",
    paid: "bg-blue-100 text-blue-800",
    preparing: "bg-purple-100 text-purple-800",
    ready: "bg-green-100 text-green-800",
    picked_up: "bg-zinc-100 text-zinc-800",
    cancelled: "bg-red-100 text-red-800",
  };

  // Count orders by status
  const statusCounts = (orders || []).reduce((acc, order) => {
    acc[order.status] = (acc[order.status] || 0) + 1;
    return acc;
  }, {} as { [key: string]: number });

  return (
    <section className="space-y-6">
      {/* Header with Cafe Selector */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-semibold">📦 Заказы</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Управление заказами вашего кафе
          </p>
          <p className="mt-1 text-sm text-zinc-600">
            {selectedCafe?.name} · {selectedCafe?.address}
          </p>
        </div>
        <select
          className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          value={selectedCafeId}
          onChange={(e) => {
            const value = e.target.value;
            window.location.href = `/cafe-owner/orders?cafe_id=${value}`;
          }}
        >
          {cafes.map((cafe: any) => (
            <option key={cafe.id} value={cafe.id}>
              {cafe.name}
            </option>
          ))}
        </select>
      </div>

      {/* Status Filter */}
      <div className="flex gap-2 overflow-x-auto border-b border-zinc-200 pb-2">
        <FilterButton
          href={`/cafe-owner/orders?cafe_id=${selectedCafeId}`}
          label="Все"
          count={orders?.length || 0}
          isActive={!statusFilter || statusFilter === "all"}
        />
        <FilterButton
          href={`/cafe-owner/orders?cafe_id=${selectedCafeId}&status=paid`}
          label="Оплачено"
          count={statusCounts["paid"] || 0}
          isActive={statusFilter === "paid"}
        />
        <FilterButton
          href={`/cafe-owner/orders?cafe_id=${selectedCafeId}&status=preparing`}
          label="Готовится"
          count={statusCounts["preparing"] || 0}
          isActive={statusFilter === "preparing"}
        />
        <FilterButton
          href={`/cafe-owner/orders?cafe_id=${selectedCafeId}&status=ready`}
          label="Готово"
          count={statusCounts["ready"] || 0}
          isActive={statusFilter === "ready"}
        />
        <FilterButton
          href={`/cafe-owner/orders?cafe_id=${selectedCafeId}&status=picked_up`}
          label="Выдано"
          count={statusCounts["picked_up"] || 0}
          isActive={statusFilter === "picked_up"}
        />
      </div>

      {/* Orders List */}
      {orders && orders.length > 0 ? (
        <div className="space-y-4">
          {orders.map((order: any) => (
            <div
              key={order.id}
              className="rounded-lg border border-zinc-200 bg-white p-6"
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3">
                    <h3 className="text-lg font-semibold">
                      Заказ #{order.id.slice(0, 8)}
                    </h3>
                    <span
                      className={`rounded-full px-3 py-1 text-xs font-medium ${
                        statusColors[order.status] || "bg-zinc-100 text-zinc-800"
                      }`}
                    >
                      {statusLabels[order.status] || order.status}
                    </span>
                  </div>
                  <div className="mt-2 text-sm text-zinc-600">
                    <p>
                      Клиент:{" "}
                      {order.profiles?.full_name ||
                        order.profiles?.phone ||
                        "Неизвестно"}
                    </p>
                    <p>
                      Создан:{" "}
                      {new Date(order.created_at).toLocaleString("ru-RU")}
                    </p>
                    {order.pickup_time && (
                      <p>
                        Время получения:{" "}
                        {new Date(order.pickup_time).toLocaleString("ru-RU")}
                      </p>
                    )}
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-2xl font-bold">
                    {order.total_credits} кр.
                  </p>
                  {order.qr_code && (
                    <p className="mt-1 text-xs text-zinc-500">
                      QR: {order.qr_code}
                    </p>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="rounded-lg border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <div className="mb-4 text-6xl">📦</div>
          <h3 className="mb-2 text-lg font-semibold">Нет заказов</h3>
          <p className="text-sm text-zinc-600">
            {statusFilter && statusFilter !== "all"
              ? "Нет заказов с выбранным статусом"
              : "Пока не было заказов в этом кафе"}
          </p>
        </div>
      )}
    </section>
  );
}

function FilterButton({
  href,
  label,
  count,
  isActive,
}: {
  href: string;
  label: string;
  count: number;
  isActive: boolean;
}) {
  return (
    <a
      href={href}
      className={`flex-shrink-0 rounded-lg px-4 py-2 text-sm font-medium ${
        isActive
          ? "bg-blue-600 text-white"
          : "bg-white text-zinc-700 hover:bg-zinc-50"
      } border ${isActive ? "border-blue-600" : "border-zinc-300"}`}
    >
      {label} ({count})
    </a>
  );
}
