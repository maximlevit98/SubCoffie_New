"use client";

import { useMemo, useState, useTransition } from "react";

import type { OrderRecord } from "../../../lib/supabase/queries/orders";
import { redeemOrderByQr } from "./actions";

type OrdersClientProps = {
  initialOrders: OrderRecord[];
};

const statusLabel = (status: string | null) => {
  if (!status) return "—";
  if (status.toLowerCase() === "issued") return "Issued";
  return status;
};

export default function OrdersClient({ initialOrders }: OrdersClientProps) {
  const [orders, setOrders] = useState<OrderRecord[]>(initialOrders);
  const [token, setToken] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const hasOrders = useMemo(() => orders.length > 0, [orders.length]);

  const handleRedeem = () => {
    setError(null);
    setSuccess(null);

    startTransition(async () => {
      const result = await redeemOrderByQr(token);
      if (!result.ok) {
        setError(result.error ?? "Не удалось выдать заказ.");
        return;
      }

      if (result.orderId) {
        setOrders((prev) =>
          prev.map((order) =>
            order.id === result.orderId
              ? {
                  ...order,
                  status: result.status ?? "issued",
                  issued_at: result.issuedAt ?? order.issued_at,
                }
              : order,
          ),
        );
      }

      setSuccess("Заказ выдан.");
      setToken("");
    });
  };

  return (
    <section className="space-y-6">
      <div className="rounded border border-zinc-200 bg-white p-4">
        <h3 className="text-sm font-semibold text-zinc-700">
          Сканировать QR / Ввести код
        </h3>
        <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-end">
          <label className="grid flex-1 gap-1 text-xs text-zinc-600">
            Token
            <input
              type="text"
              value={token}
              onChange={(event) => setToken(event.target.value)}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="Введите QR-токен"
              disabled={isPending}
            />
          </label>
          <button
            type="button"
            onClick={handleRedeem}
            disabled={isPending}
            className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
          >
            {isPending ? "Выдаём..." : "Подтвердить выдачу"}
          </button>
        </div>
        {error && (
          <div className="mt-3 rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {error}
          </div>
        )}
        {success && (
          <div className="mt-3 rounded border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            {success}
          </div>
        )}
      </div>

      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Order ID</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Issued at</th>
              <th className="px-4 py-3 font-medium">Cafe</th>
              <th className="px-4 py-3 font-medium">Phone</th>
              <th className="px-4 py-3 font-medium">Created</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {orders.map((order) => (
              <tr key={order.id} className="text-zinc-700">
                <td className="px-4 py-3 font-mono text-xs text-zinc-900">
                  {order.id}
                </td>
                <td className="px-4 py-3">{statusLabel(order.status)}</td>
                <td className="px-4 py-3">
                  {order.issued_at
                    ? new Date(order.issued_at).toLocaleString()
                    : "—"}
                </td>
                <td className="px-4 py-3 font-mono text-xs">
                  {order.cafe_id ?? "—"}
                </td>
                <td className="px-4 py-3">{order.customer_phone ?? "—"}</td>
                <td className="px-4 py-3">
                  {order.created_at
                    ? new Date(order.created_at).toLocaleString()
                    : "—"}
                </td>
              </tr>
            ))}
            {!hasOrders && (
              <tr>
                <td className="px-4 py-6 text-sm text-zinc-500" colSpan={6}>
                  Заказы не найдены.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
