import { createServerClient } from "../../../lib/supabase/server";
import { getUserRole } from "../../../lib/supabase/roles";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string }>;
};

export default async function CafeOwnerCustomersPage({
  searchParams,
}: PageProps) {
  const params = await searchParams;
  const cafeId = params?.cafe_id;

  const { userId } = await getUserRole();
  const supabase = await createServerClient();

  // Get owner's cafes
  const { data: cafes, error: cafesError } = await supabase.rpc(
    "get_owner_cafes"
  );

  if (cafesError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Клиенты</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки данных: {cafesError.message}
        </p>
      </section>
    );
  }

  if (!cafes || cafes.length === 0) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Клиенты</h2>
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

  // Fetch customer stats - get unique customers who ordered from this cafe
  const { data: customerOrders } = await supabase
    .from("orders")
    .select(
      `
      user_id,
      total_credits,
      status,
      created_at,
      profiles:user_id (
        phone,
        full_name
      )
    `
    )
    .eq("cafe_id", selectedCafeId)
    .in("status", ["paid", "preparing", "ready", "picked_up"]);

  // Group by user_id
  const customerMap = new Map();
  customerOrders?.forEach((order: any) => {
    const userId = order.user_id;
    if (!customerMap.has(userId)) {
      customerMap.set(userId, {
        user_id: userId,
        phone: order.profiles?.phone,
        full_name: order.profiles?.full_name,
        orders_count: 0,
        total_spent: 0,
        first_order: order.created_at,
        last_order: order.created_at,
      });
    }
    const customer = customerMap.get(userId);
    customer.orders_count++;
    customer.total_spent += order.total_credits || 0;
    if (new Date(order.created_at) < new Date(customer.first_order)) {
      customer.first_order = order.created_at;
    }
    if (new Date(order.created_at) > new Date(customer.last_order)) {
      customer.last_order = order.created_at;
    }
  });

  const customers = Array.from(customerMap.values()).sort(
    (a, b) => b.total_spent - a.total_spent
  );

  const selectedCafe = cafes.find((c: any) => c.id === selectedCafeId);

  return (
    <section className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-semibold">👥 База клиентов</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Информация о ваших клиентах
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
            window.location.href = `/cafe-owner/customers?cafe_id=${value}`;
          }}
        >
          {cafes.map((cafe: any) => (
            <option key={cafe.id} value={cafe.id}>
              {cafe.name}
            </option>
          ))}
        </select>
      </div>

      {/* Statistics */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <p className="text-sm text-zinc-600">Всего клиентов</p>
          <p className="mt-2 text-3xl font-bold">{customers.length}</p>
        </div>
        <div className="rounded-lg border border-green-200 bg-green-50 p-6">
          <p className="text-sm text-zinc-600">Возвращающиеся</p>
          <p className="mt-2 text-3xl font-bold text-green-700">
            {customers.filter((c) => c.orders_count > 1).length}
          </p>
        </div>
        <div className="rounded-lg border border-blue-200 bg-blue-50 p-6">
          <p className="text-sm text-zinc-600">Средний чек</p>
          <p className="mt-2 text-3xl font-bold text-blue-700">
            {customers.length > 0
              ? Math.round(
                  customers.reduce((sum, c) => sum + c.total_spent, 0) /
                    customers.reduce((sum, c) => sum + c.orders_count, 0)
                )
              : 0}{" "}
            кр.
          </p>
        </div>
        <div className="rounded-lg border border-purple-200 bg-purple-50 p-6">
          <p className="text-sm text-zinc-600">Всего заказов</p>
          <p className="mt-2 text-3xl font-bold text-purple-700">
            {customers.reduce((sum, c) => sum + c.orders_count, 0)}
          </p>
        </div>
      </div>

      {/* Customers List */}
      {customers.length > 0 ? (
        <div className="rounded-lg border border-zinc-200 bg-white">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-zinc-200 bg-zinc-50 text-left text-zinc-600">
                <tr>
                  <th className="px-6 py-3 font-medium">Клиент</th>
                  <th className="px-6 py-3 text-right font-medium">Заказов</th>
                  <th className="px-6 py-3 text-right font-medium">
                    Потрачено
                  </th>
                  <th className="px-6 py-3 text-right font-medium">
                    Средний чек
                  </th>
                  <th className="px-6 py-3 font-medium">Первый заказ</th>
                  <th className="px-6 py-3 font-medium">Последний заказ</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {customers.map((customer: any) => (
                  <tr key={customer.user_id} className="text-zinc-700">
                    <td className="px-6 py-4">
                      <div>
                        <p className="font-medium">
                          {customer.full_name || "Не указано"}
                        </p>
                        <p className="text-xs text-zinc-500">
                          {customer.phone || ""}
                        </p>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <span className="font-semibold">
                        {customer.orders_count}
                      </span>
                      {customer.orders_count > 1 && (
                        <span className="ml-2 rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                          VIP
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-right font-semibold">
                      {Math.round(customer.total_spent)} кр.
                    </td>
                    <td className="px-6 py-4 text-right text-zinc-500">
                      {Math.round(customer.total_spent / customer.orders_count)}{" "}
                      кр.
                    </td>
                    <td className="px-6 py-4 text-zinc-500">
                      {new Date(customer.first_order).toLocaleDateString(
                        "ru-RU"
                      )}
                    </td>
                    <td className="px-6 py-4 text-zinc-500">
                      {new Date(customer.last_order).toLocaleDateString(
                        "ru-RU"
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="rounded-lg border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <div className="mb-4 text-6xl">👥</div>
          <h3 className="mb-2 text-lg font-semibold">Пока нет клиентов</h3>
          <p className="text-sm text-zinc-600">
            Клиенты появятся здесь после первых заказов
          </p>
        </div>
      )}
    </section>
  );
}
