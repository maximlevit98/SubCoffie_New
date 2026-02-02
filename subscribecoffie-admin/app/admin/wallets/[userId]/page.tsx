import Link from "next/link";

import { getUserWallet, getUserTransactions } from "../actions";
import { AddTransactionForm } from "./AddTransactionForm";

type WalletDetailsPageProps = {
  params: {
    userId: string;
  };
};

export default async function WalletDetailsPage({
  params,
}: WalletDetailsPageProps) {
  let wallet: any = null;
  let transactions: any[] = [];
  let error: string | null = null;

  try {
    [wallet, transactions] = await Promise.all([
      getUserWallet(params.userId),
      getUserTransactions(params.userId, 100),
    ]);
  } catch (e: any) {
    error = e.message;
  }

  if (error || !wallet) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошелёк</h2>
          <Link
            href="/admin/wallets"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к кошелькам
          </Link>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить кошелёк: {error ?? "Not found"}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Управление кошельком</h2>
          <p className="text-sm text-zinc-500 mt-1">
            User ID: {params.userId.slice(0, 8)}...
          </p>
        </div>
        <Link
          href="/admin/wallets"
          className="text-sm text-zinc-600 hover:text-zinc-900"
        >
          ← Назад к кошелькам
        </Link>
      </div>

      {/* Wallet Info */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <p className="text-sm text-zinc-500">Текущий баланс</p>
          <p className="text-3xl font-bold mt-2">{wallet.balance || 0} кр.</p>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <p className="text-sm text-zinc-500">Бонусный баланс</p>
          <p className="text-3xl font-bold mt-2 text-emerald-600">
            {wallet.bonus_balance || 0} кр.
          </p>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <p className="text-sm text-zinc-500">Всего пополнено</p>
          <p className="text-3xl font-bold mt-2 text-zinc-500">
            {wallet.lifetime_topup || 0} кр.
          </p>
        </div>
      </div>

      {/* Add Transaction Form */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">
          Начислить или списать средства
        </h3>
        <AddTransactionForm userId={params.userId} />
      </div>

      {/* Transactions History */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">История транзакций</h3>

        {!transactions || transactions.length === 0 ? (
          <p className="text-sm text-zinc-500">Транзакции не найдены</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="border-b border-zinc-200 text-zinc-600">
                <tr>
                  <th className="py-3 px-4 text-left font-medium">Дата</th>
                  <th className="py-3 px-4 text-left font-medium">Тип</th>
                  <th className="py-3 px-4 text-left font-medium">Описание</th>
                  <th className="py-3 px-4 text-right font-medium">
                    Баланс до
                  </th>
                  <th className="py-3 px-4 text-right font-medium">Сумма</th>
                  <th className="py-3 px-4 text-right font-medium">
                    Баланс после
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {transactions.map((tx: any) => (
                  <tr key={tx.id} className="text-zinc-700">
                    <td className="py-3 px-4 text-xs">
                      {new Date(tx.created_at).toLocaleString("ru-RU")}
                    </td>
                    <td className="py-3 px-4">
                      <TransactionTypeBadge type={tx.type} />
                    </td>
                    <td className="py-3 px-4 text-zinc-600">
                      {tx.description || "—"}
                    </td>
                    <td className="py-3 px-4 text-right text-zinc-500">
                      {tx.balance_before} кр.
                    </td>
                    <td className="py-3 px-4 text-right">
                      <TransactionAmount type={tx.type} amount={tx.amount} />
                    </td>
                    <td className="py-3 px-4 text-right font-medium">
                      {tx.balance_after} кр.
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

// Transaction Type Badge
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

// Transaction Amount
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
      className={`font-semibold ${
        isCredit ? "text-green-600" : isDebit ? "text-red-600" : ""
      }`}
    >
      {isCredit ? "+" : isDebit ? "−" : ""}
      {amount} кр.
    </span>
  );
}
