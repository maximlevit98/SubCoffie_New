import Link from "next/link";
import { createServerClient } from "@/lib/supabase/server";
import { getUserRole } from "@/lib/supabase/roles";
import { redirect } from "next/navigation";
import {
  listOwnerWallets,
  getOwnerWalletsStats,
  type OwnerWalletsStats,
} from "@/lib/supabase/queries/owner-wallets";
import { type AdminWallet } from "@/lib/supabase/queries/wallets";

type OwnerWalletsPageProps = {
  searchParams: Promise<{
    search?: string;
    cafe_id?: string;
    sort?: string;
    page?: string;
    limit?: string;
  }>;
};

export default async function OwnerWalletsPage({
  searchParams,
}: OwnerWalletsPageProps) {
  // Auth check
  const { role, userId } = await getUserRole();

  if (!role || !userId) {
    redirect("/login");
  }

  if (role !== "owner" && role !== "admin") {
    redirect("/admin/owner/dashboard");
  }

  const params = await searchParams;
  const search = params.search || "";
  const cafeFilter = params.cafe_id;
  const sortBy = params.sort || "last_activity";
  const page = parseInt(params.page || "1", 10);
  const limit = parseInt(params.limit || "50", 10);
  const offset = (page - 1) * limit;

  // Get owner cafes for filter dropdown
  const supabase = await createServerClient();
  const { data: ownerCafes } = await supabase.rpc("get_owner_cafes");
  const cafes = ownerCafes || [];

  let wallets: AdminWallet[] | null = null;
  let stats: OwnerWalletsStats | null = null;
  let error: string | null = null;

  try {
    const [walletsResult, statsResult] = await Promise.all([
      listOwnerWallets({
        limit,
        offset,
        search: search || undefined,
        cafe_id: cafeFilter || undefined,
        sort_by: sortBy as "balance" | "lifetime" | "last_activity",
        sort_order: "desc",
      }),
      getOwnerWalletsStats(),
    ]);

    wallets = walletsResult.data;
    error = walletsResult.error;
    stats = statsResult.data;
  } catch (e) {
    error = e instanceof Error ? e.message : "Unknown error";
  }

  // Error state
  if (error) {
    return (
      <section className="space-y-4 p-6">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">💰 Кошельки кафе</h2>
          <span className="text-sm text-red-600">Ошибка загрузки</span>
        </div>
        <div className="rounded-lg border border-red-200 bg-red-50 p-6">
          <div className="flex items-start gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <h3 className="mb-2 font-semibold text-red-900">
                Не удалось загрузить кошельки
              </h3>
              <p className="text-sm text-red-700">{error}</p>
            </div>
          </div>
        </div>
      </section>
    );
  }

  const hasMore = (wallets?.length || 0) === limit;

  return (
    <section className="space-y-6 p-6">
      {/* Header */}
      <div>
        <div className="mb-4 flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-semibold">💰 Кошельки кафе</h2>
            <p className="mt-1 text-sm text-zinc-500">
              Кошельки клиентов ваших кофеен (Cafe Wallet)
            </p>
          </div>
          <span className="text-sm text-emerald-600">✓ Owner RPC</span>
        </div>

        {/* Stats Cards */}
        {stats && <OwnerWalletStatsCards stats={stats} />}

        {/* Filters */}
        <div className="mt-6">
          <OwnerWalletsFilters
            currentSearch={search}
            currentCafeId={cafeFilter}
            currentSort={sortBy}
            cafes={cafes}
            totalResults={wallets?.length || 0}
            hasMore={hasMore}
          />
        </div>
      </div>

      {/* Wallets Table */}
      <div className="overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-zinc-200">
            <thead className="bg-zinc-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Пользователь
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Контакты
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Кофейня
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Баланс
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Пополнено
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Последняя активность
                </th>
                <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Активность
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-zinc-500">
                  Действия
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 bg-white">
              {!wallets || wallets.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-4 py-12 text-center">
                    <div className="flex flex-col items-center gap-3">
                      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-zinc-100">
                        <span className="text-3xl">💳</span>
                      </div>
                      <div>
                        <h3 className="text-sm font-medium text-zinc-900">
                          Кошельки не найдены
                        </h3>
                        <p className="mt-1 text-sm text-zinc-500">
                          {search || cafeFilter
                            ? "Попробуйте изменить фильтры поиска"
                            : "Кошельки появятся после того, как клиенты создадут Cafe Wallet для ваших кофеен"}
                        </p>
                      </div>
                    </div>
                  </td>
                </tr>
              ) : (
                wallets.map((wallet) => (
                  <OwnerWalletRow key={wallet.wallet_id} wallet={wallet} />
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination info */}
        {wallets && wallets.length > 0 && (
          <div className="flex items-center justify-between border-t border-zinc-200 bg-zinc-50 px-4 py-3">
            <div className="text-sm text-zinc-500">
              Показано {offset + 1}–
              {Math.min(offset + limit, offset + wallets.length)} кошельков
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

// Owner Wallet Row Component
function OwnerWalletRow({ wallet }: { wallet: AdminWallet }) {
  const lastActivity =
    wallet.last_transaction_at ||
    wallet.last_payment_at ||
    wallet.last_order_at;
  const activityDate = lastActivity ? new Date(lastActivity) : null;

  return (
    <tr className="transition-colors hover:bg-zinc-50">
      {/* User */}
      <td className="px-4 py-3">
        <div className="flex flex-col">
          <span className="text-sm font-medium text-zinc-900">
            {wallet.user_full_name || "—"}
          </span>
          <span className="text-xs font-mono text-zinc-400">
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
            <span className="font-mono text-zinc-600">
              📱 {wallet.user_phone}
            </span>
          )}
          {!wallet.user_email && !wallet.user_phone && (
            <span className="text-zinc-400">—</span>
          )}
        </div>
      </td>

      {/* Cafe */}
      <td className="px-4 py-3">
        <div className="flex flex-col gap-1">
          {wallet.cafe_name ? (
            <>
              <span className="text-sm font-medium text-zinc-700">
                {wallet.cafe_name}
              </span>
              {wallet.network_name && (
                <span className="text-xs text-zinc-500">
                  {wallet.network_name}
                </span>
              )}
            </>
          ) : (
            <span className="text-sm text-zinc-400">—</span>
          )}
        </div>
      </td>

      {/* Balance */}
      <td className="px-4 py-3 text-right">
        <span className="text-sm font-semibold text-zinc-900">
          {wallet.balance_credits}
        </span>
        <span className="ml-1 text-xs text-zinc-500">кр.</span>
      </td>

      {/* Lifetime Top Up */}
      <td className="px-4 py-3 text-right">
        <span className="text-sm font-medium text-emerald-600">
          {wallet.lifetime_top_up_credits}
        </span>
        <span className="ml-1 text-xs text-zinc-500">кр.</span>
      </td>

      {/* Last Activity */}
      <td className="px-4 py-3">
        {activityDate ? (
          <div className="flex flex-col">
            <span className="text-sm text-zinc-700">
              {activityDate.toLocaleDateString("ru-RU")}
            </span>
            <span className="text-xs text-zinc-400">
              {activityDate.toLocaleTimeString("ru-RU", {
                hour: "2-digit",
                minute: "2-digit",
              })}
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
          href={`/admin/owner/wallets/${wallet.wallet_id}`}
          className="inline-flex items-center gap-1 rounded-md border border-zinc-300 px-3 py-1.5 text-xs font-medium text-zinc-700 transition-colors hover:border-zinc-400 hover:bg-zinc-50"
        >
          Детали
          <span className="text-zinc-400">→</span>
        </Link>
      </td>
    </tr>
  );
}

// Owner Wallet Stats Cards Component
function OwnerWalletStatsCards({ stats }: { stats: OwnerWalletsStats }) {
  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-5">
      <div className="rounded-lg border border-zinc-200 bg-white p-4">
        <p className="text-sm text-zinc-600">Всего кошельков</p>
        <p className="mt-1 text-2xl font-bold text-zinc-900">
          {stats.total_wallets}
        </p>
      </div>

      <div className="rounded-lg border border-zinc-200 bg-white p-4">
        <p className="text-sm text-zinc-600">Общий баланс</p>
        <p className="mt-1 text-2xl font-bold text-emerald-600">
          {stats.total_balance_credits.toLocaleString("ru-RU")}
        </p>
        <p className="text-xs text-zinc-500">кредитов</p>
      </div>

      <div className="rounded-lg border border-zinc-200 bg-white p-4">
        <p className="text-sm text-zinc-600">Пополнено</p>
        <p className="mt-1 text-2xl font-bold text-blue-600">
          +{stats.total_topups_credits.toLocaleString("ru-RU")}
        </p>
        <p className="text-xs text-zinc-500">кредитов</p>
      </div>

      <div className="rounded-lg border border-zinc-200 bg-white p-4">
        <p className="text-sm text-zinc-600">Списано</p>
        <p className="mt-1 text-2xl font-bold text-red-600">
          -{stats.total_payments_credits.toLocaleString("ru-RU")}
        </p>
        <p className="text-xs text-zinc-500">кредитов</p>
      </div>

      <div className="rounded-lg border border-zinc-200 bg-white p-4">
        <p className="text-sm text-zinc-600">Изменение (net)</p>
        <p
          className={`mt-1 text-2xl font-bold ${
            stats.net_change_credits >= 0 ? "text-emerald-600" : "text-red-600"
          }`}
        >
          {stats.net_change_credits >= 0 ? "+" : ""}
          {stats.net_change_credits.toLocaleString("ru-RU")}
        </p>
        <p className="text-xs text-zinc-500">кредитов</p>
      </div>
    </div>
  );
}

// Owner Wallets Filters Component
function OwnerWalletsFilters({
  currentSearch,
  currentCafeId,
  currentSort,
  cafes,
  totalResults,
  hasMore,
}: {
  currentSearch: string;
  currentCafeId?: string;
  currentSort: string;
  cafes: { id: string; name: string }[];
  totalResults: number;
  hasMore: boolean;
}) {
  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-4">
      <form method="get" className="space-y-3">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          {/* Search */}
          <div>
            <label
              htmlFor="search"
              className="mb-1 block text-xs font-medium text-zinc-700"
            >
              Поиск
            </label>
            <input
              type="text"
              id="search"
              name="search"
              defaultValue={currentSearch}
              placeholder="Имя, email, телефон..."
              className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
            />
          </div>

          {/* Cafe Filter */}
          <div>
            <label
              htmlFor="cafe_id"
              className="mb-1 block text-xs font-medium text-zinc-700"
            >
              Кофейня
            </label>
            <select
              id="cafe_id"
              name="cafe_id"
              defaultValue={currentCafeId || ""}
              className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
            >
              <option value="">Все кофейни</option>
              {cafes.map((cafe) => (
                <option key={cafe.id} value={cafe.id}>
                  {cafe.name}
                </option>
              ))}
            </select>
          </div>

          {/* Sort */}
          <div>
            <label
              htmlFor="sort"
              className="mb-1 block text-xs font-medium text-zinc-700"
            >
              Сортировка
            </label>
            <select
              id="sort"
              name="sort"
              defaultValue={currentSort}
              className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
            >
              <option value="last_activity">По последней активности</option>
              <option value="balance">По балансу</option>
              <option value="lifetime">По сумме пополнений</option>
            </select>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center justify-between gap-2">
          <button
            type="submit"
            className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Применить фильтры
          </button>

          <div className="text-sm text-zinc-600">
            {totalResults > 0
              ? `Найдено: ${totalResults} ${hasMore ? "+" : ""}`
              : "Нет результатов"}
          </div>
        </div>
      </form>
    </div>
  );
}
