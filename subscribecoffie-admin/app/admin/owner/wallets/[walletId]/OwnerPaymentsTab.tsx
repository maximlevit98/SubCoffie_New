"use client";

import { type AdminWalletPayment } from "@/lib/supabase/queries/wallets";

type OwnerPaymentsTabProps = {
  payments: AdminWalletPayment[];
  currentPage: number;
  hasMore: boolean;
  onPageChange: (page: number) => void;
};

export function OwnerPaymentsTab({
  payments,
  currentPage,
  hasMore,
  onPageChange,
}: OwnerPaymentsTabProps) {
  if (!payments || payments.length === 0) {
    return (
      <div className="rounded-lg border border-zinc-200 bg-white p-12 text-center">
        <div className="flex flex-col items-center gap-3">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-zinc-100">
            <span className="text-3xl">💰</span>
          </div>
          <div>
            <h3 className="text-sm font-medium text-zinc-900">
              Платежи не найдены
            </h3>
            <p className="mt-1 text-sm text-zinc-500">
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
      <div className="overflow-hidden rounded-lg border border-zinc-200 bg-white">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-zinc-200">
            <thead className="bg-zinc-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Дата/время
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Тип операции
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Статус
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Сумма
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Комиссия
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Net Amount
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Детали
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 bg-white">
              {payments.map((payment) => (
                <tr key={payment.payment_id} className="hover:bg-zinc-50">
                  {/* Date */}
                  <td className="whitespace-nowrap px-4 py-3 text-sm text-zinc-700">
                    <div className="flex flex-col">
                      <span>
                        {new Date(payment.created_at).toLocaleDateString(
                          "ru-RU"
                        )}
                      </span>
                      <span className="text-xs text-zinc-400">
                        {new Date(payment.created_at).toLocaleTimeString(
                          "ru-RU",
                          {
                            hour: "2-digit",
                            minute: "2-digit",
                          }
                        )}
                      </span>
                      {payment.completed_at && (
                        <span className="mt-1 text-xs text-emerald-600">
                          ✓{" "}
                          {new Date(payment.completed_at).toLocaleTimeString(
                            "ru-RU",
                            {
                              hour: "2-digit",
                              minute: "2-digit",
                            }
                          )}
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
                  <td className="whitespace-nowrap px-4 py-3 text-right text-sm font-semibold text-zinc-900">
                    {payment.amount_credits} кр.
                  </td>

                  {/* Commission */}
                  <td className="whitespace-nowrap px-4 py-3 text-right text-sm text-red-600">
                    {payment.commission_credits > 0
                      ? `−${payment.commission_credits} кр.`
                      : "—"}
                  </td>

                  {/* Net Amount */}
                  <td className="whitespace-nowrap px-4 py-3 text-right text-sm font-semibold text-emerald-600">
                    {payment.net_amount} кр.
                  </td>

                  {/* Details */}
                  <td className="px-4 py-3 text-sm">
                    <div className="flex flex-col gap-1">
                      {payment.order_number && (
                        <span className="text-xs text-blue-600">
                          📦 {payment.order_number}
                        </span>
                      )}
                      {payment.provider_transaction_id && (
                        <span className="font-mono text-xs text-zinc-400">
                          {payment.provider_transaction_id.slice(0, 12)}...
                        </span>
                      )}
                      {!payment.order_number &&
                        !payment.provider_transaction_id && (
                          <span className="text-xs text-zinc-400">—</span>
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
      <div className="flex items-center justify-between rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3">
        <div className="text-sm text-zinc-500">
          Страница {currentPage} • Показано {payments.length} записей
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

// Helper components
function TransactionTypeBadge({ type }: { type: string }) {
  const config: Record<string, { label: string; color: string }> = {
    topup: { label: "Пополнение", color: "bg-green-100 text-green-700" },
    payment: { label: "Оплата", color: "bg-blue-100 text-blue-700" },
    refund: { label: "Возврат", color: "bg-purple-100 text-purple-700" },
  };

  const c = config[type] || {
    label: type,
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
    completed: { label: "Завершён", color: "bg-green-100 text-green-700" },
    pending: { label: "В обработке", color: "bg-yellow-100 text-yellow-700" },
    failed: { label: "Ошибка", color: "bg-red-100 text-red-700" },
    cancelled: { label: "Отменён", color: "bg-zinc-100 text-zinc-700" },
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
