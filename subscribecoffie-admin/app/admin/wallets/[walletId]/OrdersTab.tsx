"use client";

import React from "react";
import Link from "next/link";
import { type AdminWalletOrder } from "../../../../lib/supabase/queries/wallets";

type OrdersTabProps = {
  orders: AdminWalletOrder[];
  currentPage: number;
  hasMore: boolean;
  onPageChange: (page: number) => void;
};

export function OrdersTab({
  orders,
  currentPage,
  hasMore,
  onPageChange,
}: OrdersTabProps) {
  if (!orders || orders.length === 0) {
    return (
      <div className="rounded-lg border border-zinc-200 bg-white p-12 text-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-16 h-16 rounded-full bg-zinc-100 flex items-center justify-center">
            <span className="text-3xl">🛒</span>
          </div>
          <div>
            <h3 className="text-sm font-medium text-zinc-900">Заказы не найдены</h3>
            <p className="text-sm text-zinc-500 mt-1">
              История заказов пуста
            </p>
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
      <div className="flex items-center justify-between px-4 py-3 bg-zinc-50 rounded-lg border border-zinc-200">
        <div className="text-sm text-zinc-500">
          Страница {currentPage} • Показано {orders.length} заказов
        </div>
        
        <div className="flex items-center gap-2">
          <button
            onClick={() => onPageChange(currentPage - 1)}
            disabled={currentPage <= 1}
            className="px-3 py-1 text-xs font-medium text-zinc-700 border border-zinc-300 rounded hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed"
          >
            ← Назад
          </button>
          <button
            onClick={() => onPageChange(currentPage + 1)}
            disabled={!hasMore}
            className="px-3 py-1 text-xs font-medium text-zinc-700 border border-zinc-300 rounded hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed"
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
    <div className="rounded-lg border border-zinc-200 bg-white overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 bg-zinc-50 border-b border-zinc-200">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-3 mb-2">
              <Link
                href={`/admin/orders/${order.order_id}`}
                className="text-lg font-semibold text-blue-600 hover:text-blue-800"
              >
                {order.order_number}
              </Link>
              <OrderStatusBadge status={order.status} />
              {order.payment_status && (
                <PaymentStatusBadge status={order.payment_status} />
              )}
            </div>
            
            <div className="flex items-center gap-4 text-sm text-zinc-500">
              <span>📅 {new Date(order.created_at).toLocaleString("ru-RU")}</span>
              {order.cafe_name && (
                <span>🏪 {order.cafe_name}</span>
              )}
            </div>
          </div>

          <div className="text-right">
            <div className="text-2xl font-bold text-zinc-900">
              {order.paid_credits} кр.
            </div>
            {order.bonus_used > 0 && (
              <div className="text-xs text-emerald-600 mt-1">
                +{order.bonus_used} кр. бонусами
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Items */}
      {order.items && order.items.length > 0 && (
        <div className="px-6 py-4">
          <h4 className="text-sm font-semibold text-zinc-700 mb-3">Состав заказа</h4>
          <div className="space-y-2">
            {order.items.map((item) => (
              <div
                key={item.item_id}
                className="flex items-center justify-between py-2 border-b border-zinc-100 last:border-0"
              >
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-zinc-900">
                      {item.item_name}
                    </span>
                    <span className="text-xs text-zinc-500">
                      × {item.qty}
                    </span>
                  </div>
                  
                  {item.modifiers ? (
                    <div className="text-xs text-zinc-500 mt-1">
                      <ModifiersDisplay modifiers={item.modifiers} />
                    </div>
                  ) : null}
                </div>

                <div className="text-right ml-4">
                  <div className="text-sm font-medium text-zinc-900">
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

      {/* Footer with totals */}
      <div className="px-6 py-4 bg-zinc-50 border-t border-zinc-200">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4 text-sm">
            {order.customer_name && (
              <span className="text-zinc-600">
                👤 {order.customer_name}
              </span>
            )}
            {order.customer_phone && (
              <span className="text-zinc-600 font-mono">
                📱 {order.customer_phone}
              </span>
            )}
            {order.payment_method && (
              <span className="text-zinc-500">
                💳 {order.payment_method}
              </span>
            )}
          </div>

          <div className="text-right">
            <div className="space-y-1 text-sm">
              <div className="flex items-center justify-between gap-4">
                <span className="text-zinc-500">Подытог:</span>
                <span className="font-medium text-zinc-700">{order.subtotal_credits} кр.</span>
              </div>
              
              {order.bonus_used > 0 && (
                <div className="flex items-center justify-between gap-4">
                  <span className="text-emerald-600">Бонусы:</span>
                  <span className="font-medium text-emerald-600">−{order.bonus_used} кр.</span>
                </div>
              )}
              
              <div className="flex items-center justify-between gap-4 pt-1 border-t border-zinc-200">
                <span className="font-semibold text-zinc-900">Оплачено:</span>
                <span className="text-lg font-bold text-zinc-900">{order.paid_credits} кр.</span>
              </div>
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
    pending: { label: "Ожидание", color: "bg-amber-100 text-amber-700" },
    confirmed: { label: "Подтверждён", color: "bg-blue-100 text-blue-700" },
    preparing: { label: "Готовится", color: "bg-cyan-100 text-cyan-700" },
    ready: { label: "Готов", color: "bg-emerald-100 text-emerald-700" },
    issued: { label: "Выдан", color: "bg-green-100 text-green-700" },
    picked_up: { label: "Получен", color: "bg-green-100 text-green-700" },
    cancelled: { label: "Отменён", color: "bg-red-100 text-red-700" },
  };

  const c = config[status] || { label: status, color: "bg-zinc-100 text-zinc-700" };

  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${c.color}`}>
      {c.label}
    </span>
  );
}

function PaymentStatusBadge({ status }: { status: string }) {
  const config: Record<string, { label: string; color: string }> = {
    pending: { label: "К оплате", color: "bg-amber-100 text-amber-700" },
    paid: { label: "Оплачен", color: "bg-emerald-100 text-emerald-700" },
    failed: { label: "Ошибка оплаты", color: "bg-red-100 text-red-700" },
    refunded: { label: "Возврат", color: "bg-purple-100 text-purple-700" },
  };

  const c = config[status] || { label: status, color: "bg-zinc-100 text-zinc-700" };

  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${c.color}`}>
      💳 {c.label}
    </span>
  );
}

function ModifiersDisplay({ modifiers }: { modifiers: unknown }): React.ReactNode {
  if (!modifiers) return null;
  
  let modArray: unknown[] = [];
  
  try {
    modArray = Array.isArray(modifiers) ? modifiers : JSON.parse(String(modifiers));
  } catch {
    return (
      <span className="text-zinc-400 italic">
        Модификаторы: {String(modifiers).slice(0, 50)}...
      </span>
    );
  }
  
  if (!Array.isArray(modArray) || modArray.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-wrap gap-1">
      {modArray.map((mod, idx: number) => {
        const typedMod = mod as { name?: string; value?: string };
        return (
          <span key={idx} className="inline-block px-1.5 py-0.5 bg-zinc-100 rounded text-xs">
            {typedMod.name || typedMod.value || JSON.stringify(mod)}
          </span>
        );
      })}
    </div>
  );
}
