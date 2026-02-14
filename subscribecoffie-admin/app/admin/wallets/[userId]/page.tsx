import Link from "next/link";

import { getUserWallets, getUserTransactions } from "../actions";
import { AddTransactionForm } from "./AddTransactionForm";

type WalletDetailsPageProps = {
  params: {
    userId: string;
  };
};

export default async function WalletDetailsPage({
  params,
}: WalletDetailsPageProps) {
  let wallets: any[] = [];
  let transactions: any[] = [];
  let error: string | null = null;

  try {
    wallets = await getUserWallets(params.userId);
    
    // Get transactions for all wallets
    if (wallets.length > 0) {
      const allTransactions = await Promise.all(
        wallets.map((w: any) => getUserTransactions(w.id, 50))
      );
      transactions = allTransactions.flat().sort((a, b) => 
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );
    }
  } catch (e: any) {
    error = e.message;
  }

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошельки пользователя</h2>
          <Link
            href="/admin/wallets"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к кошелькам
          </Link>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить кошельки: {error}
        </p>
      </section>
    );
  }

  if (wallets.length === 0) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошельки пользователя</h2>
          <Link
            href="/admin/wallets"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к кошелькам
          </Link>
        </div>
        <p className="rounded border border-zinc-200 bg-zinc-50 p-3 text-sm text-zinc-500">
          У пользователя нет кошельков
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Кошельки пользователя</h2>
          <p className="text-sm text-zinc-500 mt-1">
            User ID: {params.userId.slice(0, 8)}... | Кошельков: {wallets.length}
          </p>
        </div>
        <Link
          href="/admin/wallets"
          className="text-sm text-zinc-600 hover:text-zinc-900"
        >
          ← Назад к кошелькам
        </Link>
      </div>

      {/* Wallets Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {wallets.map((wallet: any) => (
          <WalletCard key={wallet.id} wallet={wallet} />
        ))}
      </div>

      {/* Add Transaction Form */}
      <div className="rounded-lg border-2 border-amber-200 bg-amber-50 p-6">
        <div className="flex items-start gap-4">
          <div className="flex-shrink-0 w-12 h-12 bg-amber-100 rounded-full flex items-center justify-center">
            <span className="text-2xl">⚠️</span>
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-semibold text-amber-900 mb-2">
              Ручные операции временно недоступны
            </h3>
            <div className="space-y-2 text-sm text-amber-800">
              <p>
                <strong>Причина:</strong> RPC функция <code className="bg-amber-200 px-1 py-0.5 rounded text-xs">add_wallet_transaction</code> была удалена в ходе миграции на каноническую схему (20260205000003_unify_wallets_schema.sql).
              </p>
              <p>
                <strong>Решение:</strong> Backend-агент может добавить новую безопасную RPC функцию для админ-операций с учётом множественных кошельков (citypass + cafe_wallet).
              </p>
              <div className="mt-4 p-3 bg-white rounded border border-amber-300">
                <p className="text-xs font-medium text-amber-900 mb-2">
                  Требуемая функциональность:
                </p>
                <ul className="text-xs text-amber-700 space-y-1 list-disc list-inside">
                  <li>Начисление/списание на конкретный кошелёк (wallet_id)</li>
                  <li>Создание транзакции с типом admin_credit/admin_debit</li>
                  <li>Обновление balance_credits с проверкой достаточности средств</li>
                  <li>Логирование операций админа</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
        
        {/* Placeholder form (disabled) */}
        <div className="mt-6 opacity-50 pointer-events-none">
          <AddTransactionForm userId={params.userId} />
        </div>
      </div>

      {/* Transactions History */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">
          История транзакций (все кошельки)
        </h3>

        {!transactions || transactions.length === 0 ? (
          <p className="text-sm text-zinc-500">Транзакции не найдены</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="border-b border-zinc-200 text-zinc-600">
                <tr>
                  <th className="py-3 px-4 text-left font-medium">Дата</th>
                  <th className="py-3 px-4 text-left font-medium">Кошелёк</th>
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
                {transactions.map((tx: any) => {
                  const wallet = wallets.find((w: any) => w.id === tx.wallet_id);
                  return (
                    <tr key={tx.id} className="text-zinc-700">
                      <td className="py-3 px-4 text-xs">
                        {new Date(tx.created_at).toLocaleString("ru-RU")}
                      </td>
                      <td className="py-3 px-4 text-xs">
                        <WalletTypeBadge wallet={wallet} />
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
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </section>
  );
}

// Wallet Card Component
function WalletCard({ wallet }: { wallet: any }) {
  const isCityPass = wallet.wallet_type === "citypass";
  
  return (
    <div className={`rounded-lg border-2 p-6 ${
      isCityPass 
        ? "border-blue-200 bg-blue-50" 
        : "border-green-200 bg-green-50"
    }`}>
      {/* Header */}
      <div className="flex items-start justify-between mb-4">
        <div>
          <span className={`inline-block rounded-full px-3 py-1 text-xs font-medium ${
            isCityPass 
              ? "bg-blue-100 text-blue-700" 
              : "bg-green-100 text-green-700"
          }`}>
            {isCityPass ? "CityPass" : "Cafe Wallet"}
          </span>
          {!isCityPass && (
            <p className="text-sm font-medium text-zinc-700 mt-2">
              {wallet.cafe_name || wallet.network_name || "—"}
            </p>
          )}
        </div>
        <span className="text-xs text-zinc-400">
          ID: {wallet.id.slice(0, 8)}...
        </span>
      </div>

      {/* Balance */}
      <div className="mb-4">
        <p className="text-sm text-zinc-600">Баланс</p>
        <p className="text-3xl font-bold text-zinc-900 mt-1">
          {wallet.balance_credits || 0} <span className="text-lg">кр.</span>
        </p>
      </div>

      {/* Lifetime topup */}
      <div className="pt-4 border-t border-zinc-200">
        <div className="flex justify-between items-center">
          <span className="text-xs text-zinc-500">Всего пополнено:</span>
          <span className="text-sm font-medium text-emerald-600">
            {wallet.lifetime_top_up_credits || 0} кр.
          </span>
        </div>
        <div className="flex justify-between items-center mt-2">
          <span className="text-xs text-zinc-500">Создан:</span>
          <span className="text-xs text-zinc-600">
            {new Date(wallet.created_at).toLocaleDateString("ru-RU")}
          </span>
        </div>
      </div>
    </div>
  );
}

// Wallet Type Badge (for transactions table)
function WalletTypeBadge({ wallet }: { wallet: any }) {
  if (!wallet) return <span className="text-zinc-400">—</span>;
  
  const isCityPass = wallet.wallet_type === "citypass";
  return (
    <span className={`inline-block rounded px-2 py-0.5 text-xs ${
      isCityPass 
        ? "bg-blue-100 text-blue-700" 
        : "bg-green-100 text-green-700"
    }`}>
      {isCityPass ? "CP" : wallet.cafe_name?.slice(0, 12) || "Cafe"}
    </span>
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
