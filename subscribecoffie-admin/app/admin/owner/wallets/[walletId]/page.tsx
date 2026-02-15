import Link from "next/link";
import { redirect } from "next/navigation";

import { OwnerSidebar } from "@/components/OwnerSidebar";
import {
  getOwnerCafesForFilters,
  getOwnerWalletOrders,
  getOwnerWalletOverview,
  getOwnerWalletPayments,
  getOwnerWalletTransactions,
  listOwnerWallets,
} from "@/lib/supabase/queries/owner-wallets";
import { getUserRole } from "@/lib/supabase/roles";
import { WalletDetailClient } from "../../../wallets/[walletId]/WalletDetailClient";

type OwnerWalletDetailsPageProps = {
  params: Promise<{
    walletId: string;
  }>;
};

export default async function OwnerWalletDetailsPage({
  params,
}: OwnerWalletDetailsPageProps) {
  const { walletId } = await params;
  const { role, userId } = await getUserRole();

  if (!userId) {
    redirect("/login");
  }

  if (role !== "owner") {
    redirect("/admin/dashboard");
  }

  const [{ data: cafes }, { data: overview, error: overviewError }] = await Promise.all([
    getOwnerCafesForFilters(),
    getOwnerWalletOverview(walletId),
  ]);

  const cafesCount = cafes?.length || 0;

  if (overviewError) {
    return renderErrorState(overviewError, cafesCount);
  }

  if (!overview) {
    return renderNotFoundState(cafesCount);
  }

  const [
    { data: transactions, error: transactionsError },
    { data: payments, error: paymentsError },
    { data: orders, error: ordersError },
    { data: relatedWallets },
  ] = await Promise.all([
    getOwnerWalletTransactions(walletId, 50, 0),
    getOwnerWalletPayments(walletId, 50, 0),
    getOwnerWalletOrders(walletId, 50, 0),
    listOwnerWallets({ limit: 500, offset: 0 }),
  ]);

  const dataError = transactionsError || paymentsError || ordersError;
  if (dataError) {
    return renderErrorState(dataError, cafesCount);
  }

  const userWallets = (relatedWallets || []).filter(
    (wallet) => wallet.user_id === overview.user_id
  );

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="account" cafesCount={cafesCount} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          {userWallets.length > 1 && (
            <div className="mb-6 rounded-lg border border-blue-200 bg-blue-50 p-4">
              <p className="text-sm font-medium text-blue-900">
                У клиента {userWallets.length} кошельков в ваших кофейнях
              </p>
              <div className="mt-2 flex flex-wrap gap-2">
                {userWallets.map((wallet) => (
                  <Link
                    key={wallet.wallet_id}
                    href={`/admin/owner/wallets/${wallet.wallet_id}`}
                    className={`inline-flex items-center rounded px-2 py-1 text-xs font-medium ${
                      wallet.wallet_id === walletId
                        ? "bg-blue-600 text-white"
                        : "bg-blue-100 text-blue-700 hover:bg-blue-200"
                    }`}
                  >
                    {wallet.cafe_name || "Кофейня"} • {wallet.balance_credits} кр.
                  </Link>
                ))}
              </div>
            </div>
          )}

          <WalletDetailClient
            overview={overview}
            transactions={transactions || []}
            payments={payments || []}
            orders={orders || []}
            title="Кошелёк клиента"
            backHref="/admin/owner/wallets"
            showUserProfileLink={false}
            userProfileHref={null}
            orderDetailsBaseHref=""
          />
        </div>
      </main>
    </div>
  );
}

function renderErrorState(error: string, cafesCount: number) {
  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="account" cafesCount={cafesCount} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-semibold">Кошелёк клиента</h2>
            <Link
              href="/admin/owner/wallets"
              className="text-sm text-zinc-600 hover:text-zinc-900"
            >
              ← Назад к кошелькам
            </Link>
          </div>
          <div className="rounded-lg border border-red-200 bg-red-50 p-6">
            <p className="text-sm font-medium text-red-900">Ошибка загрузки</p>
            <p className="mt-1 text-sm text-red-700">{error}</p>
          </div>
        </div>
      </main>
    </div>
  );
}

function renderNotFoundState(cafesCount: number) {
  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="account" cafesCount={cafesCount} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-semibold">Кошелёк клиента</h2>
            <Link
              href="/admin/owner/wallets"
              className="text-sm text-zinc-600 hover:text-zinc-900"
            >
              ← Назад к кошелькам
            </Link>
          </div>
          <div className="rounded-lg border border-amber-200 bg-amber-50 p-6 text-sm text-amber-800">
            Кошелёк не найден или недоступен.
          </div>
        </div>
      </main>
    </div>
  );
}
