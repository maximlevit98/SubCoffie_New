import Link from "next/link";
import { redirect } from "next/navigation";

import {
  getWalletsByUserId,
  getWalletOverview,
  getWalletTransactionsAdmin,
  getWalletPayments,
  getWalletOrders,
} from "../../../../lib/supabase/queries/wallets";
import { WalletDetailClient } from "./WalletDetailClient";

type WalletDetailsPageProps = {
  params: Promise<{
    walletId: string;
  }>;
};

export default async function WalletDetailsPage({
  params,
}: WalletDetailsPageProps) {
  const { walletId: identifier } = await params;
  let error: string | null = null;

  // Primary path: identifier is wallet_id
  const { data: directOverview, error: directOverviewError } = await getWalletOverview(identifier);

  // Backward compatibility path: identifier might be old user_id links
  if (!directOverview && !directOverviewError) {
    const { data: legacyWallets, error: legacyWalletsError } = await getWalletsByUserId(identifier);

    if (legacyWalletsError) {
      error = legacyWalletsError;
    } else if (legacyWallets && legacyWallets.length > 0) {
      redirect(`/admin/wallets/${legacyWallets[0].id}`);
    }
  }

  if (directOverviewError) {
    error = directOverviewError;
  }

  if (error) {
    return renderErrorState(error);
  }

  if (!directOverview) {
    return renderNotFoundState();
  }

  const walletId = directOverview.wallet_id;

  // Load wallet details (history + peer wallets)
  const [
    { data: transactions, error: transactionsError },
    { data: payments, error: paymentsError },
    { data: orders, error: ordersError },
    { data: userWallets, error: userWalletsError },
  ] = await Promise.all([
    getWalletTransactionsAdmin(walletId, 50, 0),
    getWalletPayments(walletId, 50, 0),
    getWalletOrders(walletId, 50, 0),
    getWalletsByUserId(directOverview.user_id),
  ]);

  if (transactionsError || paymentsError || ordersError || userWalletsError) {
    error = transactionsError || paymentsError || ordersError || userWalletsError || "Unknown error";
  }

  if (error) {
    return renderErrorState(error);
  }

  const wallets = userWallets || [];

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
                Отображается кошелёк: <strong>{directOverview.wallet_type === "citypass" ? "CityPass" : "Cafe Wallet"}</strong>
                {directOverview.cafe_name && ` (${directOverview.cafe_name})`}
              </p>
              <div className="mt-2 flex flex-wrap gap-2">
                {wallets.map((w) => (
                  <Link
                    key={w.id}
                    href={`/admin/wallets/${w.id}`}
                    className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium ${
                      w.id === walletId
                        ? "bg-blue-600 text-white"
                        : "bg-blue-100 text-blue-700 hover:bg-blue-200"
                    }`}
                  >
                    {w.wallet_type === "citypass" ? "CityPass" : w.cafe_name || "Cafe Wallet"}
                    {" • "}
                    {w.balance_credits} кр.
                  </Link>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      <WalletDetailClient
        overview={directOverview}
        transactions={transactions || []}
        payments={payments || []}
        orders={orders || []}
      />
    </section>
  );
}

function renderErrorState(error: string) {
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

function renderNotFoundState() {
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
          Кошелёк не найден
        </p>
      </div>
    </section>
  );
}
