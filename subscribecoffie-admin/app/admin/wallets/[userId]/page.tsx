import Link from "next/link";

import {
  getWalletsByUserId,
  getWalletOverview,
  getWalletTransactionsAdmin,
  getWalletPayments,
  getWalletOrders,
} from "../../../../lib/supabase/queries/wallets";
import { WalletDetailClient } from "./WalletDetailClient";

type WalletDetailsPageProps = {
  params: {
    userId: string;
  };
};

export default async function WalletDetailsPage({
  params,
}: WalletDetailsPageProps) {
  let error: string | null = null;

  // Step 1: Get user's wallets to find wallet_id
  const { data: wallets, error: walletsError } = await getWalletsByUserId(params.userId);
  
  if (walletsError) {
    error = walletsError;
  }

  if (!wallets || wallets.length === 0) {
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
        <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-12 text-center">
          <div className="flex flex-col items-center gap-3">
            <div className="w-16 h-16 rounded-full bg-zinc-100 flex items-center justify-center">
              <span className="text-3xl">💳</span>
            </div>
            <div>
              <h3 className="text-sm font-medium text-zinc-900">Кошельки не найдены</h3>
              <p className="text-sm text-zinc-500 mt-1">
                У этого пользователя нет кошельков
              </p>
            </div>
          </div>
        </div>
      </section>
    );
  }

  // For now, display first wallet (typically CityPass)
  // TODO: Add wallet selector if multiple wallets
  const primaryWallet = wallets[0];
  const walletId = primaryWallet.id;

  // Step 2: Fetch detailed data for this wallet
  const [
    { data: overview, error: overviewError },
    { data: transactions, error: transactionsError },
    { data: payments, error: paymentsError },
    { data: orders, error: ordersError },
  ] = await Promise.all([
    getWalletOverview(walletId),
    getWalletTransactionsAdmin(walletId, 50, 0),
    getWalletPayments(walletId, 50, 0),
    getWalletOrders(walletId, 50, 0),
  ]);

  if (overviewError || transactionsError || paymentsError || ordersError) {
    error = overviewError || transactionsError || paymentsError || ordersError || "Unknown error";
  }

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошелёк пользователя</h2>
          <Link
            href="/admin/wallets"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к кошелькам
          </Link>
        </div>
        <div className="rounded-lg border border-red-200 bg-red-50 p-6">
          <div className="flex items-start gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <h3 className="font-semibold text-red-900 mb-2">Ошибка загрузки данных</h3>
              <p className="text-sm text-red-700">{error}</p>
            </div>
          </div>
        </div>
      </section>
    );
  }

  if (!overview) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошелёк пользователя</h2>
          <Link
            href="/admin/wallets"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к кошелькам
          </Link>
        </div>
        <div className="rounded-lg border border-amber-200 bg-amber-50 p-6">
          <p className="text-sm text-amber-800">
            Не удалось загрузить данные кошелька
          </p>
        </div>
      </section>
    );
  }

  return (
    <section>
      {/* Multiple wallets indicator */}
      {wallets.length > 1 && (
        <div className="mb-6 rounded-lg border border-blue-200 bg-blue-50 p-4">
          <div className="flex items-start gap-3">
            <span className="text-xl">ℹ️</span>
            <div className="flex-1">
              <p className="text-sm text-blue-900 font-medium mb-1">
                У пользователя {wallets.length} кошельков
              </p>
              <p className="text-sm text-blue-700">
                Отображается кошелёк: <strong>{primaryWallet.wallet_type === "citypass" ? "CityPass" : "Cafe Wallet"}</strong>
                {primaryWallet.cafe_name && ` (${primaryWallet.cafe_name})`}
              </p>
              <div className="mt-2 flex flex-wrap gap-2">
                {wallets.map((w) => (
                  <span
                    key={w.id}
                    className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium ${
                      w.id === walletId
                        ? "bg-blue-600 text-white"
                        : "bg-blue-100 text-blue-700"
                    }`}
                  >
                    {w.wallet_type === "citypass" ? "CityPass" : w.cafe_name || "Cafe Wallet"}
                    {" • "}
                    {w.balance_credits} кр.
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      <WalletDetailClient
        overview={overview}
        transactions={transactions || []}
        payments={payments || []}
        orders={orders || []}
      />
    </section>
  );
}
