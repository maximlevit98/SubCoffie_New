"use client";

import Link from "next/link";
import { type AdminWalletPayment } from "../../../../lib/supabase/queries/wallets";

type PaymentsTabProps = {
  payments: AdminWalletPayment[];
  currentPage: number;
  hasMore: boolean;
  onPageChange: (page: number) => void;
};

export function PaymentsTab({
  payments,
  currentPage,
  hasMore,
  onPageChange,
}: PaymentsTabProps) {
  if (!payments || payments.length === 0) {
    return (
      <div className="rounded-lg border border-zinc-200 bg-white p-12 text-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-16 h-16 rounded-full bg-zinc-100 flex items-center justify-center">
            <span className="text-3xl">💰</span>
          </div>
          <div>
            <h3 className="text-sm font-medium text-zinc-900">Платежи не найдены</h3>
            <p className="text-sm text-zinc-500 mt-1">
              История платёжных транзакций пуста
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Payments Table */}
      <div className="rounded-lg border border-zinc-200 bg-white overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-zinc-200">
            <thead className="bg-zinc-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Дата/время
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Тип операции
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Статус
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Сумма
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Комиссия
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Net Amount
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Детали
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-zinc-100">
              {payments.map((payment) => (
                <tr key={payment.payment_id} className="hover:bg-zinc-50">
                  {/* Date */}
                  <td className="px-4 py-3 text-sm text-zinc-700 whitespace-nowrap">
                    <div className="flex flex-col">
                      <span>{new Date(payment.created_at).toLocaleDateString("ru-RU")}</span>
                      <span className="text-xs text-zinc-400">
                        {new Date(payment.created_at).toLocaleTimeString("ru-RU", {
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </span>
                      {payment.completed_at && (
                        <span className="text-xs text-emerald-600 mt-1">
                          ✓ {new Date(payment.completed_at).toLocaleTimeString("ru-RU", {
                            hour: "2-digit",
                            minute: "2-digit",
                          })}
                        </span>
                      )}
                    </div>
                  </td>

                  {/* Transaction Type */}
                  <td className="px-4 py-3">
                    <TransactionTypeBadge type={payment.transaction_type} />
                  </td>

                  {/* Status */}
                  <td className="px-4 py-3">
                    <PaymentStatusBadge status={payment.status} />
                  </td>

                  {/* Amount */}
                  <td className="px-4 py-3 text-right text-sm font-semibold text-zinc-900 whitespace-nowrap">
                    {payment.amount_credits} кр.
                  </td>

                  {/* Commission */}
                  <td className="px-4 py-3 text-right text-sm text-zinc-500 whitespace-nowrap">
                    {payment.commission_credits > 0 ? (
                      <span className="text-red-600">−{payment.commission_credits} кр.</span>
                    ) : (
                      "—"
                    )}
                  </td>

                  {/* Net Amount */}
                  <td className="px-4 py-3 text-right text-sm font-semibold text-emerald-600 whitespace-nowrap">
                    {payment.net_amount} кр.
                  </td>

                  {/* Details */}
                  <td className="px-4 py-3 text-xs">
                    <div className="flex flex-col gap-1 max-w-xs">
                      {payment.order_id && (
                        <Link
                          href={`/admin/orders/${payment.order_id}`}
                          className="text-blue-600 hover:text-blue-800 underline"
                        >
                          📦 {payment.order_number || payment.order_id.slice(0, 8)}
                        </Link>
                      )}
                      
                      {payment.payment_method_id && (
                        <span className="text-zinc-500">
                          Method: {payment.payment_method_id.slice(0, 8)}...
                        </span>
                      )}
                      
                      {payment.provider_transaction_id && (
                        <span className="text-zinc-500 font-mono">
                          Provider: {payment.provider_transaction_id.slice(0, 12)}...
                        </span>
                      )}
                      
                      {payment.idempotency_key && (
                        <span className="text-zinc-400 font-mono">
                          Idempotency: {payment.idempotency_key.slice(0, 12)}...
                        </span>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between px-4 py-3 bg-zinc-50 rounded-lg border border-zinc-200">
        <div className="text-sm text-zinc-500">
          Страница {currentPage} • Показано {payments.length} записей
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

// Helper components
function TransactionTypeBadge({ type }: { type: string }) {
  const config: Record<string, { label: string; color: string }> = {
    topup: { label: "Пополнение", color: "bg-green-100 text-green-700" },
    order_payment: { label: "Оплата заказа", color: "bg-blue-100 text-blue-700" },
    payment: { label: "Оплата", color: "bg-blue-100 text-blue-700" },
    refund: { label: "Возврат", color: "bg-purple-100 text-purple-700" },
  };

  const c = config[type] || { label: type, color: "bg-zinc-100 text-zinc-700" };

  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${c.color}`}>
      {c.label}
    </span>
  );
}

function PaymentStatusBadge({ status }: { status: string }) {
  const config: Record<string, { label: string; color: string }> = {
    pending: { label: "Ожидание", color: "bg-amber-100 text-amber-700" },
    completed: { label: "Завершено", color: "bg-emerald-100 text-emerald-700" },
    failed: { label: "Ошибка", color: "bg-red-100 text-red-700" },
    cancelled: { label: "Отменено", color: "bg-zinc-100 text-zinc-700" },
    refunded: { label: "Возвращено", color: "bg-purple-100 text-purple-700" },
  };

  const c = config[status] || { label: status, color: "bg-zinc-100 text-zinc-700" };

  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${c.color}`}>
      {c.label}
    </span>
  );
}
