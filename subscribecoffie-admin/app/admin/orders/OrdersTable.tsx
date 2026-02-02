"use client";

import Link from "next/link";

type Order = {
  id: string;
  cafe_id: string;
  customer_phone: string;
  status: string;
  paid_credits: number;
  created_at: string;
  items_count: number;
};

type OrdersTableProps = {
  orders: Order[];
};

export function OrdersTable({ orders }: OrdersTableProps) {
  const statusColors: Record<string, string> = {
    created: "bg-zinc-100 text-zinc-700",
    paid: "bg-blue-100 text-blue-700",
    preparing: "bg-amber-100 text-amber-700",
    ready: "bg-emerald-100 text-emerald-700",
    issued: "bg-green-100 text-green-700",
    cancelled: "bg-red-100 text-red-700",
    refunded: "bg-purple-100 text-purple-700",
  };

  return (
    <div className="overflow-x-auto rounded-lg border border-zinc-200 bg-white">
      <table className="min-w-full text-left text-sm">
        <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
          <tr>
            <th className="px-4 py-3 font-medium">ID заказа</th>
            <th className="px-4 py-3 font-medium">Телефон</th>
            <th className="px-4 py-3 font-medium">Статус</th>
            <th className="px-4 py-3 font-medium">Позиций</th>
            <th className="px-4 py-3 font-medium">Сумма</th>
            <th className="px-4 py-3 font-medium">Дата</th>
            <th className="px-4 py-3 font-medium"></th>
          </tr>
        </thead>
        <tbody className="divide-y divide-zinc-100">
          {orders.length === 0 ? (
            <tr>
              <td className="px-4 py-8 text-center text-zinc-500" colSpan={7}>
                Заказы не найдены
              </td>
            </tr>
          ) : (
            orders.map((order) => (
              <tr key={order.id} className="text-zinc-700 hover:bg-zinc-50">
                <td className="px-4 py-3 font-mono text-xs">
                  {order.id.slice(0, 8)}...
                </td>
                <td className="px-4 py-3">{order.customer_phone || "—"}</td>
                <td className="px-4 py-3">
                  <span
                    className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                      statusColors[order.status] ||
                      "bg-zinc-100 text-zinc-700"
                    }`}
                  >
                    {order.status}
                  </span>
                </td>
                <td className="px-4 py-3">{order.items_count}</td>
                <td className="px-4 py-3 font-medium">
                  {order.paid_credits} кр.
                </td>
                <td className="px-4 py-3 text-xs text-zinc-500">
                  {new Date(order.created_at).toLocaleString("ru-RU")}
                </td>
                <td className="px-4 py-3">
                  <Link
                    href={`/admin/orders/${order.id}`}
                    className="inline-flex items-center rounded border border-zinc-300 px-3 py-1 text-xs font-medium hover:bg-zinc-50"
                  >
                    Открыть →
                  </Link>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
