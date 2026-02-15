"use client";

import { type AdminWalletTransaction } from "@/lib/supabase/queries/wallets";

type OwnerTransactionsTabProps = {
  transactions: AdminWalletTransaction[];
  currentPage: number;
  hasMore: boolean;
  onPageChange: (page: number) => void;
};

export function OwnerTransactionsTab({
  transactions,
  currentPage,
  hasMore,
  onPageChange,
}: OwnerTransactionsTabProps) {
  if (!transactions || transactions.length === 0) {
    return (
      <div className="rounded-lg border border-zinc-200 bg-white p-12 text-center">
        <div className="flex flex-col items-center gap-3">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-zinc-100">
            <span className="text-3xl">💳</span>
          </div>
          <div>
            <h3 className="text-sm font-medium text-zinc-900">
              Транзакции не найдены
            </h3>
            <p className="mt-1 text-sm text-zinc-500">История транзакций пуста</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Transactions Table */}
      <div className="overflow-hidden rounded-lg border border-zinc-200 bg-white">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-zinc-200">
            <thead className="bg-zinc-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Дата/время
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Тип
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Описание
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Баланс до
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Сумма
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Баланс после
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Связи
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 bg-white">
              {transactions.map((tx) => (
                <tr key={tx.transaction_id} className="hover:bg-zinc-50">
                  {/* Date */}
                  <td className="whitespace-nowrap px-4 py-3 text-sm text-zinc-700">
                    <div className="flex flex-col">
                      <span>
                        {new Date(tx.created_at).toLocaleDateString("ru-RU")}
                      </span>
                      <span className="text-xs text-zinc-400">
                        {new Date(tx.created_at).toLocaleTimeString("ru-RU", {
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </span>
                    </div>
                  </td>

                  {/* Type */}
                  <td className="px-4 py-3">
                    <TransactionTypeBadge type={tx.type} />
                  </td>

                  {/* Description */}
                  <td className="max-w-xs px-4 py-3 text-sm text-zinc-600">
                    <div className="flex flex-col gap-1">
                      <span>{tx.description || "—"}</span>
                      {tx.actor_full_name && (
                        <span className="text-xs text-zinc-400">
                          Инициатор: {tx.actor_full_name}
                          {tx.actor_email && ` (${tx.actor_email})`}
                        </span>
                      )}
                    </div>
                  </td>

                  {/* Balance Before */}
                  <td className="whitespace-nowrap px-4 py-3 text-right text-sm text-zinc-500">
                    {tx.balance_before} кр.
                  </td>

                  {/* Amount */}
                  <td className="whitespace-nowrap px-4 py-3 text-right">
                    <TransactionAmount type={tx.type} amount={tx.amount} />
                  </td>

                  {/* Balance After */}
                  <td className="whitespace-nowrap px-4 py-3 text-right text-sm font-semibold text-zinc-900">
                    {tx.balance_after} кр.
                  </td>

                  {/* Relations */}
                  <td className="px-4 py-3 text-sm">
                    <div className="flex flex-col gap-1">
                      {tx.order_id && (
                        <span className="text-xs text-blue-600">
                          📦 {tx.order_number || tx.order_id.slice(0, 8)}
                        </span>
                      )}
                      {!tx.order_id && (
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
          Страница {currentPage} • Показано {transactions.length} записей
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
    bonus: { label: "Бонус", color: "bg-emerald-100 text-emerald-700" },
    payment: { label: "Оплата", color: "bg-blue-100 text-blue-700" },
    refund: { label: "Возврат", color: "bg-purple-100 text-purple-700" },
    admin_credit: {
      label: "Начисление",
      color: "bg-green-100 text-green-700",
    },
    admin_debit: { label: "Списание", color: "bg-red-100 text-red-700" },
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

function TransactionAmount({
  type,
  amount,
}: {
  type: string;
  amount: number;
}) {
  const isCredit = ["topup", "bonus", "refund", "admin_credit"].includes(type);
  const isDebit = ["payment", "admin_debit"].includes(type);

  return (
    <span
      className={`text-sm font-semibold ${
        isCredit
          ? "text-green-600"
          : isDebit
            ? "text-red-600"
            : "text-zinc-900"
      }`}
    >
      {isCredit ? "+" : isDebit ? "−" : ""}
      {amount} кр.
    </span>
  );
}
