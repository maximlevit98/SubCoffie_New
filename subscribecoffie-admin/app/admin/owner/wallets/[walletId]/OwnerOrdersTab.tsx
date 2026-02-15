"use client";

import React from "react";
import { type AdminWalletOrder } from "@/lib/supabase/queries/wallets";

type OwnerOrdersTabProps = {
  orders: AdminWalletOrder[];
  currentPage: number;
  hasMore: boolean;
  onPageChange: (page: number) => void;
};

export function OwnerOrdersTab({
  orders,
  currentPage,
  hasMore,
  onPageChange,
}: OwnerOrdersTabProps) {
  if (!orders || orders.length === 0) {
    return (
      <div className="rounded-lg border border-zinc-200 bg-white p-12 text-center">
        <div className="flex flex-col items-center gap-3">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-zinc-100">
            <span className="text-3xl">🛒</span>
          </div>
          <div>
            <h3 className="text-sm font-medium text-zinc-900">
              Заказы не найдены
            </h3>
            <p className="mt-1 text-sm text-zinc-500">История заказов пуста</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Orders List */}
      <div className="space-y-4">
        {orders.map((order) => (
          <OrderCard key={order.order_id} order={order} />
        ))}
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3">
        <div className="text-sm text-zinc-500">
          Страница {currentPage} • Показано {orders.length} заказов
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => onPageChange(currentPage - 1)}
            disabled={currentPage <= 1}
            className="rounded border border-zinc-300 px-3 py-1 text-xs font-medium text-zinc-700 hover:bg-white disabled:cursor-not-allowed disabled:opacity-50"
          >
            ← Назад
          </button>
          <button
            onClick={() => onPageChange(currentPage + 1)}
            disabled={!hasMore}
            className="rounded border border-zinc-300 px-3 py-1 text-xs font-medium text-zinc-700 hover:bg-white disabled:cursor-not-allowed disabled:opacity-50"
          >
            Вперёд →
          </button>
        </div>
      </div>
    </div>
  );
}

// Order Card Component
function OrderCard({ order }: { order: AdminWalletOrder }) {
  return (
    <div className="overflow-hidden rounded-lg border border-zinc-200 bg-white">
      {/* Header */}
      <div className="border-b border-zinc-200 bg-zinc-50 px-6 py-4">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="mb-2 flex items-center gap-3">
              <span className="text-lg font-semibold text-zinc-900">
                {order.order_number}
              </span>
              <OrderStatusBadge status={order.status} />
              {order.payment_status && (
                <PaymentStatusBadge status={order.payment_status} />
              )}
            </div>

            <div className="flex items-center gap-4 text-sm text-zinc-500">
              <span>
                📅 {new Date(order.created_at).toLocaleString("ru-RU")}
              </span>
              {order.cafe_name && <span>🏪 {order.cafe_name}</span>}
            </div>
          </div>

          <div className="text-right">
            <div className="text-2xl font-bold text-zinc-900">
              {order.paid_credits} кр.
            </div>
            {order.bonus_used > 0 && (
              <div className="mt-1 text-xs text-emerald-600">
                +{order.bonus_used} кр. бонусами
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Items */}
      {order.items && order.items.length > 0 && (
        <div className="px-6 py-4">
          <h4 className="mb-3 text-sm font-semibold text-zinc-700">
            Состав заказа
          </h4>
          <div className="space-y-2">
            {order.items.map((item, idx) => (
              <div
                key={idx}
                className="flex items-center justify-between rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3"
              >
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-zinc-900">
                      {item.item_name}
                    </span>
                    <span className="rounded bg-zinc-200 px-2 py-0.5 text-xs font-medium text-zinc-700">
                      × {item.qty}
                    </span>
                  </div>
                  {item.modifiers !== null && item.modifiers !== undefined && (
                    <div className="mt-1 text-xs text-zinc-500">
                      Модификаторы: {JSON.stringify(item.modifiers)}
                    </div>
                  )}
                </div>
                <div className="text-right">
                  <div className="text-sm font-semibold text-zinc-900">
                    {item.line_total_credits} кр.
                  </div>
                  <div className="text-xs text-zinc-500">
                    {item.unit_price_credits} кр. × {item.qty}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Customer Info */}
      {(order.customer_name || order.customer_phone) && (
        <div className="border-t border-zinc-200 bg-zinc-50 px-6 py-3">
          <div className="flex items-center gap-4 text-sm text-zinc-600">
            {order.customer_name && <span>👤 {order.customer_name}</span>}
            {order.customer_phone && (
              <span className="font-mono">📱 {order.customer_phone}</span>
            )}
          </div>
        </div>
      )}

      {/* Footer with totals */}
      <div className="border-t border-zinc-200 bg-white px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="text-sm text-zinc-600">
            {order.payment_method && (
              <span>Способ оплаты: {order.payment_method}</span>
            )}
          </div>
          <div className="flex items-center gap-4">
            <div className="text-sm text-zinc-600">
              Сумма заказа:{" "}
              <span className="font-semibold text-zinc-900">
                {order.subtotal_credits} кр.
              </span>
            </div>
            {order.bonus_used > 0 && (
              <div className="text-sm text-emerald-600">
                Бонусы: +{order.bonus_used} кр.
              </div>
            )}
            <div className="text-sm font-semibold text-zinc-900">
              Оплачено: {order.paid_credits} кр.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Helper components
function OrderStatusBadge({ status }: { status: string }) {
  const config: Record<string, { label: string; color: string }> = {
    pending: { label: "Ожидает", color: "bg-yellow-100 text-yellow-700" },
    confirmed: { label: "Подтверждён", color: "bg-blue-100 text-blue-700" },
    preparing: { label: "Готовится", color: "bg-purple-100 text-purple-700" },
    ready: { label: "Готов", color: "bg-green-100 text-green-700" },
    completed: { label: "Завершён", color: "bg-emerald-100 text-emerald-700" },
    cancelled: { label: "Отменён", color: "bg-red-100 text-red-700" },
  };

  const c = config[status] || {
    label: status,
    color: "bg-zinc-100 text-zinc-700",
  };

  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${c.color}`}
    >
      {c.label}
    </span>
  );
}

function PaymentStatusBadge({ status }: { status: string }) {
  const config: Record<string, { label: string; color: string }> = {
    completed: { label: "Оплачено", color: "bg-green-100 text-green-700" },
    pending: { label: "Ожидает оплаты", color: "bg-yellow-100 text-yellow-700" },
    failed: { label: "Ошибка оплаты", color: "bg-red-100 text-red-700" },
    refunded: { label: "Возвращено", color: "bg-purple-100 text-purple-700" },
  };

  const c = config[status] || {
    label: status,
    color: "bg-zinc-100 text-zinc-700",
  };

  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${c.color}`}
    >
      💳 {c.label}
    </span>
  );
}
