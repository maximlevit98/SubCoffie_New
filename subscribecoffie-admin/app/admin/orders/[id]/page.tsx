import Link from "next/link";

import { getOrderDetails } from "../actions";
import { OrderStatusButtons } from "./OrderStatusButtons";

type OrderDetailsPageProps = {
  params: {
    id: string;
  };
};

export default async function OrderDetailsPage({
  params,
}: OrderDetailsPageProps) {
  let orderData: any;
  let error: string | null = null;

  try {
    orderData = await getOrderDetails(params.id);
  } catch (e: any) {
    error = e.message;
  }

  if (error || !orderData) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Заказ</h2>
          <Link
            href="/admin/orders"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к заказам
          </Link>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить заказ: {error ?? "Not found"}
        </p>
      </section>
    );
  }

  const order = orderData.order;
  const items = orderData.items || [];
  const events = orderData.events || [];
  const userProfile = order.user_profile;

  // Определяем доступные переходы статуса
  const statusFlow: Record<string, string[]> = {
    created: ["paid", "cancelled"],
    paid: ["preparing", "cancelled"],
    preparing: ["ready", "cancelled"],
    ready: ["issued", "cancelled"],
    issued: [],
    cancelled: [],
    refunded: [],
  };

  const availableStatuses = statusFlow[order.status] || [];

  return (
    <section className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Заказ #{order.id.slice(0, 8)}</h2>
          <p className="text-sm text-zinc-500 mt-1">
            {new Date(order.created_at).toLocaleString("ru-RU")}
          </p>
        </div>
        <Link
          href="/admin/orders"
          className="text-sm text-zinc-600 hover:text-zinc-900"
        >
          ← Назад к заказам
        </Link>
      </div>

      {/* Status Management */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <div className="mb-4">
          <span className="text-sm text-zinc-500">Текущий статус:</span>
          <div className="mt-2">
            <StatusBadge status={order.status} />
          </div>
        </div>

        {availableStatuses.length > 0 && (
          <div>
            <p className="text-sm text-zinc-500 mb-3">Изменить статус на:</p>
            <OrderStatusButtons
              orderId={order.id}
              currentStatus={order.status}
              availableStatuses={availableStatuses}
            />
          </div>
        )}
      </div>

      {/* Order Info */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Customer Information */}
        {userProfile && (
          <div className="rounded-lg border border-zinc-200 bg-white p-6">
            <h3 className="text-lg font-semibold mb-4">Информация о клиенте</h3>
            <div className="flex items-start gap-4 mb-4">
              {userProfile.avatar_url ? (
                <img
                  src={userProfile.avatar_url}
                  alt={userProfile.full_name || "User"}
                  className="w-16 h-16 rounded-full"
                />
              ) : (
                <div className="w-16 h-16 rounded-full bg-zinc-200 flex items-center justify-center">
                  <span className="text-xl font-semibold">
                    {(userProfile.full_name || "?").charAt(0).toUpperCase()}
                  </span>
                </div>
              )}
              <div className="flex-1">
                <h4 className="font-semibold text-lg">{userProfile.full_name || "Unknown"}</h4>
                <div className="space-y-1 mt-2 text-sm">
                  {userProfile.email && (
                    <p className="text-zinc-600">📧 {userProfile.email}</p>
                  )}
                  {userProfile.phone && (
                    <p className="text-zinc-600 font-mono">📱 {userProfile.phone}</p>
                  )}
                  {userProfile.auth_provider && (
                    <p className="text-zinc-500">
                      Регистрация: {userProfile.auth_provider === "google" && "🔵 Google"}
                      {userProfile.auth_provider === "apple" && "🍎 Apple"}
                      {userProfile.auth_provider === "email" && "📧 Email"}
                      {userProfile.auth_provider === "phone" && "📱 Phone"}
                    </p>
                  )}
                  <p className="text-zinc-400 text-xs">
                    Зарегистрирован: {new Date(userProfile.created_at).toLocaleDateString("ru-RU")}
                  </p>
                </div>
                <Link
                  href={`/admin/users/${userProfile.id}`}
                  className="inline-flex items-center mt-3 text-sm text-blue-600 hover:text-blue-700"
                >
                  Профиль пользователя →
                </Link>
              </div>
            </div>
          </div>
        )}
        
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="text-lg font-semibold mb-4">Информация о заказе</h3>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-zinc-500">ID кафе:</dt>
              <dd className="font-mono text-xs">{order.cafe_id}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-zinc-500">Телефон клиента:</dt>
              <dd className="font-medium">{order.customer_phone || "—"}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-zinc-500">Подитог:</dt>
              <dd className="font-medium">{order.subtotal_credits} кр.</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-zinc-500">Бонусы:</dt>
              <dd className="font-medium">{order.bonus_used || 0} кр.</dd>
            </div>
            <div className="flex justify-between border-t border-zinc-100 pt-2">
              <dt className="text-zinc-700 font-semibold">Итого:</dt>
              <dd className="font-semibold text-lg">{order.paid_credits} кр.</dd>
            </div>
            {order.scheduled_ready_at && (
              <div className="flex justify-between">
                <dt className="text-zinc-500">Время готовности:</dt>
                <dd className="font-medium">
                  {new Date(order.scheduled_ready_at).toLocaleString("ru-RU")}
                </dd>
              </div>
            )}
            {order.eta_sec && (
              <div className="flex justify-between">
                <dt className="text-zinc-500">ETA:</dt>
                <dd className="font-medium">{Math.round(order.eta_sec / 60)} мин</dd>
              </div>
            )}
          </dl>
        </div>

        {/* History */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="text-lg font-semibold mb-4">История статусов</h3>
          <div className="space-y-3">
            {events.length === 0 ? (
              <p className="text-sm text-zinc-500">Нет истории</p>
            ) : (
              events.map((event: any, idx: number) => (
                <div
                  key={event.id}
                  className="flex items-start gap-3 text-sm"
                >
                  <div className="mt-1">
                    <div className="w-2 h-2 rounded-full bg-emerald-500" />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <StatusBadge status={event.status} />
                      {idx === 0 && (
                        <span className="text-xs text-zinc-500">(текущий)</span>
                      )}
                    </div>
                    <p className="text-xs text-zinc-500 mt-1">
                      {new Date(event.created_at).toLocaleString("ru-RU")}
                    </p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Order Items */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">Позиции заказа</h3>
        {items.length === 0 ? (
          <p className="text-sm text-zinc-500">Нет позиций</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="border-b border-zinc-200 text-zinc-600">
                <tr>
                  <th className="py-3 px-4 text-left font-medium">Название</th>
                  <th className="py-3 px-4 text-left font-medium">Категория</th>
                  <th className="py-3 px-4 text-right font-medium">Количество</th>
                  <th className="py-3 px-4 text-right font-medium">Цена</th>
                  <th className="py-3 px-4 text-right font-medium">Итого</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {items.map((item: any) => (
                  <tr key={item.id} className="text-zinc-700">
                    <td className="py-3 px-4">{item.title}</td>
                    <td className="py-3 px-4">
                      <span className="inline-flex items-center rounded-full bg-zinc-100 px-2 py-1 text-xs text-zinc-700">
                        {item.category || "—"}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right">{item.quantity}</td>
                    <td className="py-3 px-4 text-right">{item.unit_credits} кр.</td>
                    <td className="py-3 px-4 text-right font-medium">
                      {item.line_total} кр.
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </section>
  );
}

// Status Badge Component
function StatusBadge({ status }: { status: string }) {
  const statusConfig: Record<
    string,
    { label: string; color: string }
  > = {
    created: { label: "Создан", color: "bg-zinc-100 text-zinc-700" },
    paid: { label: "Оплачен", color: "bg-blue-100 text-blue-700" },
    preparing: { label: "Готовится", color: "bg-amber-100 text-amber-700" },
    ready: { label: "Готов", color: "bg-emerald-100 text-emerald-700" },
    issued: { label: "Выдан", color: "bg-green-100 text-green-700" },
    cancelled: { label: "Отменён", color: "bg-red-100 text-red-700" },
    refunded: { label: "Возврат", color: "bg-purple-100 text-purple-700" },
  };

  const config = statusConfig[status] || {
    label: status,
    color: "bg-zinc-100 text-zinc-700",
  };

  return (
    <span
      className={`inline-flex items-center rounded-full px-3 py-1 text-sm font-medium ${config.color}`}
    >
      {config.label}
    </span>
  );
}
