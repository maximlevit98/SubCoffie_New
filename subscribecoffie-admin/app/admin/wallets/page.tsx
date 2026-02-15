import Link from "next/link";

import { listWalletsAdmin, getWalletsStats, type AdminWallet } from "../../../lib/supabase/queries/wallets";
import { WalletsFilters } from "./WalletsFilters";
import { WalletStatsCards } from "./WalletStatsCards";

type WalletsPageProps = {
  searchParams: Promise<{
    search?: string;
    type?: string;
    sort?: string;
    page?: string;
    limit?: string;
  }>;
};

export default async function WalletsPage({ searchParams }: WalletsPageProps) {
  const params = await searchParams;
  const search = params.search || "";
  const typeFilter = params.type;
  const sortBy = params.sort || "created_at";
  const page = parseInt(params.page || "1", 10);
  const limit = parseInt(params.limit || "50", 10);
  const offset = (page - 1) * limit;

  let wallets: AdminWallet[] | null = null;
  let stats: { total_wallets: number; total_balance: number; avg_balance: number; citypass_count: number; cafe_wallet_count: number } | null = null;
  let error: string | null = null;

  try {
    const [walletsResult, statsResult] = await Promise.all([
      listWalletsAdmin({
        limit,
        offset,
        search: search || undefined,
      }),
      getWalletsStats(),
    ]);

    wallets = walletsResult.data;
    error = walletsResult.error;
    stats = statsResult.data;
  } catch (e) {
    error = e instanceof Error ? e.message : "Unknown error";
  }

  // Apply type filter (client-side)
  const filteredWallets = typeFilter && wallets
    ? wallets.filter((w) => w.wallet_type === typeFilter)
    : wallets || [];

  // Apply sorting (client-side)
  const sortedWallets = [...filteredWallets].sort((a, b) => {
    switch (sortBy) {
      case "balance":
        return b.balance_credits - a.balance_credits;
      case "lifetime":
        return b.lifetime_top_up_credits - a.lifetime_top_up_credits;
      case "last_activity": {
        const aActivity = a.last_transaction_at || a.last_payment_at || a.last_order_at || a.created_at;
        const bActivity = b.last_transaction_at || b.last_payment_at || b.last_order_at || b.created_at;
        return new Date(bActivity).getTime() - new Date(aActivity).getTime();
      }
      case "created_at":
      default:
        return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    }
  });

  // Error state
  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошельки</h2>
          <span className="text-sm text-red-600">Ошибка загрузки</span>
        </div>
        <div className="rounded-lg border border-red-200 bg-red-50 p-6">
          <div className="flex items-start gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <h3 className="font-semibold text-red-900 mb-2">Не удалось загрузить кошельки</h3>
              <p className="text-sm text-red-700">{error}</p>
            </div>
          </div>
        </div>
      </section>
    );
  }

  const hasMore = (wallets?.length || 0) === limit;

  return (
    <section className="space-y-6">
      {/* Header */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-2xl font-semibold">Кошельки</h2>
            <p className="text-sm text-zinc-500 mt-1">
              Управление кошельками пользователей
            </p>
          </div>
          <span className="text-sm text-emerald-600">
            ✓ Admin RPC
          </span>
        </div>

        {/* Global Stats */}
        {stats && <WalletStatsCards stats={stats} />}

        {/* Filters */}
        <div className="mt-6">
          <WalletsFilters
            currentSearch={search}
            currentType={typeFilter}
            currentSort={sortBy}
            currentPage={page}
            currentLimit={limit}
            totalResults={sortedWallets.length}
            hasMore={hasMore}
          />
        </div>
      </div>

      {/* Wallets Table */}
      <div className="rounded-lg border border-zinc-200 bg-white shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-zinc-200">
            <thead className="bg-zinc-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Пользователь
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Контакты
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Тип кошелька
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Баланс
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Пополнено
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Последняя активность
                </th>
                <th className="px-4 py-3 text-center text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Активность
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Действия
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-zinc-100">
              {sortedWallets.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-4 py-12 text-center">
                    <div className="flex flex-col items-center gap-3">
                      <div className="w-16 h-16 rounded-full bg-zinc-100 flex items-center justify-center">
                        <span className="text-3xl">💳</span>
                      </div>
                      <div>
                        <h3 className="text-sm font-medium text-zinc-900">Кошельки не найдены</h3>
                        <p className="text-sm text-zinc-500 mt-1">
                          {search || typeFilter
                            ? "Попробуйте изменить фильтры поиска"
                            : "Кошельки появятся после регистрации пользователей"}
                        </p>
                      </div>
                    </div>
                  </td>
                </tr>
              ) : (
                sortedWallets.map((wallet) => (
                  <WalletRow key={wallet.wallet_id} wallet={wallet} />
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination info */}
        {sortedWallets.length > 0 && (
          <div className="px-4 py-3 bg-zinc-50 border-t border-zinc-200 flex items-center justify-between">
            <div className="text-sm text-zinc-500">
              Показано {offset + 1}–{Math.min(offset + limit, offset + sortedWallets.length)} кошельков
            </div>
            {hasMore && (
              <div className="text-sm text-amber-600">
                ⚠️ Есть ещё результаты, используйте пагинацию
              </div>
            )}
          </div>
        )}
      </div>
    </section>
  );
}

// Wallet Row Component
function WalletRow({ wallet }: { wallet: AdminWallet }) {
  const lastActivity = wallet.last_transaction_at || wallet.last_payment_at || wallet.last_order_at;
  const activityDate = lastActivity ? new Date(lastActivity) : null;

  return (
    <tr className="hover:bg-zinc-50 transition-colors">
      {/* User */}
      <td className="px-4 py-3">
        <div className="flex flex-col">
          <span className="text-sm font-medium text-zinc-900">
            {wallet.user_full_name || "—"}
          </span>
          <span className="text-xs text-zinc-400 font-mono">
            ID: {wallet.user_id?.slice(0, 8)}...
          </span>
        </div>
      </td>

      {/* Contacts */}
      <td className="px-4 py-3">
        <div className="flex flex-col gap-0.5 text-xs">
          {wallet.user_email && (
            <span className="text-zinc-600">✉️ {wallet.user_email}</span>
          )}
          {wallet.user_phone && (
            <span className="text-zinc-600 font-mono">📱 {wallet.user_phone}</span>
          )}
          {!wallet.user_email && !wallet.user_phone && (
            <span className="text-zinc-400">—</span>
          )}
        </div>
      </td>

      {/* Wallet Type */}
      <td className="px-4 py-3">
        <div className="flex flex-col gap-1">
          <WalletTypeBadge type={wallet.wallet_type} />
          {wallet.cafe_name && (
            <span className="text-xs text-zinc-500">{wallet.cafe_name}</span>
          )}
          {wallet.network_name && (
            <span className="text-xs text-zinc-500">{wallet.network_name}</span>
          )}
        </div>
      </td>

      {/* Balance */}
      <td className="px-4 py-3 text-right">
        <span className="text-sm font-semibold text-zinc-900">
          {wallet.balance_credits}
        </span>
        <span className="text-xs text-zinc-500 ml-1">кр.</span>
      </td>

      {/* Lifetime Top Up */}
      <td className="px-4 py-3 text-right">
        <span className="text-sm font-medium text-emerald-600">
          {wallet.lifetime_top_up_credits}
        </span>
        <span className="text-xs text-zinc-500 ml-1">кр.</span>
      </td>

      {/* Last Activity */}
      <td className="px-4 py-3">
        {activityDate ? (
          <div className="flex flex-col">
            <span className="text-sm text-zinc-700">
              {activityDate.toLocaleDateString("ru-RU")}
            </span>
            <span className="text-xs text-zinc-400">
              {activityDate.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" })}
            </span>
          </div>
        ) : (
          <span className="text-sm text-zinc-400">Нет активности</span>
        )}
      </td>

      {/* Activity Stats */}
      <td className="px-4 py-3">
        <div className="flex flex-col gap-0.5 text-xs text-zinc-600">
          <div className="flex items-center justify-center gap-1">
            <span className="text-zinc-400">Тр:</span>
            <span className="font-medium">{wallet.total_transactions}</span>
          </div>
          <div className="flex items-center justify-center gap-1">
            <span className="text-zinc-400">Зак:</span>
            <span className="font-medium">{wallet.total_orders}</span>
          </div>
        </div>
      </td>

      {/* Actions */}
      <td className="px-4 py-3 text-right">
        <Link
          href={`/admin/wallets/${wallet.user_id}`}
          className="inline-flex items-center gap-1 rounded-md border border-zinc-300 px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 hover:border-zinc-400 transition-colors"
        >
          Детали
          <span className="text-zinc-400">→</span>
        </Link>
      </td>
    </tr>
  );
}

// Wallet Type Badge
function WalletTypeBadge({ type }: { type: string }) {
  const isCityPass = type === "citypass";
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
        isCityPass
          ? "bg-blue-100 text-blue-700"
          : "bg-green-100 text-green-700"
      }`}
    >
      {isCityPass ? "CityPass" : "Cafe Wallet"}
    </span>
  );
}
