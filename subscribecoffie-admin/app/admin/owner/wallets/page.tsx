import Link from "next/link";
import {
  getOwnerCafesForFilters,
  getOwnerWalletsStats,
  listOwnerWallets,
  type OwnerWalletsStats,
} from "@/lib/supabase/queries/owner-wallets";
import type { AdminWallet } from "@/lib/supabase/queries/wallets";

type WalletsPageProps = {
  searchParams: Promise<{
    search?: string;
    cafe?: string;
    sort?: string;
    page?: string;
    limit?: string;
  }>;
};

function toInt(value: number | null | undefined): number {
  return typeof value === "number" ? value : 0;
}

function formatCredits(value: number): string {
  return `${value.toLocaleString("ru-RU")} кр.`;
}

function activityTimestamp(wallet: AdminWallet): string | null {
  return wallet.last_transaction_at || wallet.last_payment_at || wallet.last_order_at;
}

function getWalletSortValue(wallet: AdminWallet, sortBy: string): number {
  switch (sortBy) {
    case "balance":
      return toInt(wallet.balance_credits);
    case "lifetime":
      return toInt(wallet.lifetime_top_up_credits);
    case "topups":
      return toInt(wallet.total_topup_credits);
    case "spent":
      return toInt(wallet.total_spent_credits);
    case "orders":
      return toInt(wallet.total_orders);
    case "last_activity":
      return new Date(activityTimestamp(wallet) || wallet.created_at).getTime();
    case "created_at":
    default:
      return new Date(wallet.created_at).getTime();
  }
}

function buildHref(
  params: URLSearchParams,
  updates: Record<string, string | undefined>
): string {
  const next = new URLSearchParams(params.toString());
  for (const [key, value] of Object.entries(updates)) {
    if (!value) {
      next.delete(key);
    } else {
      next.set(key, value);
    }
  }
  const query = next.toString();
  return query ? `/admin/owner/wallets?${query}` : "/admin/owner/wallets";
}

export default async function OwnerWalletsPage({ searchParams }: WalletsPageProps) {
  const params = await searchParams;

  const search = (params.search || "").trim();
  const cafeFilter = params.cafe || "";
  const sortBy = params.sort || "created_at";
  const page = Math.max(1, parseInt(params.page || "1", 10) || 1);
  const limit = Math.min(100, Math.max(10, parseInt(params.limit || "50", 10) || 50));
  const offset = (page - 1) * limit;

  const [{ data: cafes, error: cafesError }, walletsResult, statsResult] = await Promise.all([
    getOwnerCafesForFilters(),
    listOwnerWallets({
      cafeId: cafeFilter || undefined,
      limit,
      offset,
      search: search || undefined,
    }),
    getOwnerWalletsStats(cafeFilter || undefined),
  ]);

  const wallets = walletsResult.data || [];
  const stats = statsResult.data;
  const error = cafesError || walletsResult.error || statsResult.error;

  const sortedWallets = [...wallets].sort(
    (a, b) => getWalletSortValue(b, sortBy) - getWalletSortValue(a, sortBy)
  );

  const hasMore = wallets.length === limit;
  const currentParams = new URLSearchParams();
  if (search) currentParams.set("search", search);
  if (cafeFilter) currentParams.set("cafe", cafeFilter);
  if (sortBy) currentParams.set("sort", sortBy);
  currentParams.set("limit", String(limit));
  currentParams.set("page", String(page));

  const prevHref = buildHref(currentParams, {
    page: page > 1 ? String(page - 1) : undefined,
  });
  const nextHref = buildHref(currentParams, {
    page: String(page + 1),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-zinc-900">Кошельки клиентов</h1>
          <p className="mt-1 text-sm text-zinc-600">
            Только кошельки ваших кофеен. CityPass кошельки в owner scope не отображаются.
          </p>
        </div>
        <span className="rounded-md bg-emerald-100 px-3 py-1 text-xs font-medium text-emerald-700">
          Owner scope
        </span>
      </div>

      {error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-5">
          <p className="text-sm font-medium text-red-800">Не удалось загрузить кошельки</p>
          <p className="mt-1 text-sm text-red-700">{error}</p>
        </div>
      ) : (
        <>
          <StatsGrid stats={stats} />

          <section className="rounded-lg border border-zinc-200 bg-white p-4">
            <form className="grid grid-cols-1 gap-4 md:grid-cols-12" method="get">
              <div className="md:col-span-4">
                <label htmlFor="search" className="mb-1 block text-xs font-medium text-zinc-600">
                  Поиск
                </label>
                <input
                  id="search"
                  name="search"
                  defaultValue={search}
                  placeholder="Email, телефон, имя, кофейня"
                  className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                />
              </div>

                  <div className="md:col-span-3">
                    <label htmlFor="cafe" className="mb-1 block text-xs font-medium text-zinc-600">
                      Кофейня
                    </label>
                    <select
                      id="cafe"
                      name="cafe"
                      defaultValue={cafeFilter}
                      className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                    >
                      <option value="">Все кофейни</option>
                      {(cafes || []).map((cafe) => (
                        <option key={cafe.id} value={cafe.id}>
                          {cafe.name || cafe.id}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="md:col-span-3">
                    <label htmlFor="sort" className="mb-1 block text-xs font-medium text-zinc-600">
                      Сортировка
                    </label>
                    <select
                      id="sort"
                      name="sort"
                      defaultValue={sortBy}
                      className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                    >
                      <option value="created_at">По дате создания</option>
                      <option value="last_activity">По активности</option>
                      <option value="balance">По балансу</option>
                      <option value="topups">По пополнениям</option>
                      <option value="spent">По списаниям</option>
                      <option value="orders">По количеству заказов</option>
                    </select>
                  </div>

                  <div className="md:col-span-2">
                    <label htmlFor="limit" className="mb-1 block text-xs font-medium text-zinc-600">
                      На странице
                    </label>
                    <select
                      id="limit"
                      name="limit"
                      defaultValue={String(limit)}
                      className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                    >
                      <option value="25">25</option>
                      <option value="50">50</option>
                      <option value="100">100</option>
                    </select>
                  </div>

                  <input type="hidden" name="page" value="1" />
                  <div className="md:col-span-12 flex items-center justify-between border-t border-zinc-200 pt-4">
                    <p className="text-xs text-zinc-500">
                      Найдено на странице:{" "}
                      <span className="font-semibold text-zinc-700">{sortedWallets.length}</span>
                    </p>
                    <div className="flex items-center gap-2">
                      <Link
                        href="/admin/owner/wallets"
                        className="rounded-md border border-zinc-300 px-3 py-2 text-sm text-zinc-600 hover:bg-zinc-50"
                      >
                        Сбросить
                      </Link>
                      <button
                        type="submit"
                        className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
                      >
                        Применить
                      </button>
                    </div>
                  </div>
            </form>
          </section>

          <section className="overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm">
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-zinc-200">
                    <thead className="bg-zinc-50">
                      <tr>
                        <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">
                          Клиент
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">
                          Кофейня
                        </th>
                        <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">
                          Баланс
                        </th>
                        <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">
                          Пополнено
                        </th>
                        <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">
                          Списано
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">
                          Активность
                        </th>
                        <th className="px-4 py-3 text-center text-xs font-medium uppercase text-zinc-500">
                          Операции
                        </th>
                        <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">
                          Детали
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-zinc-100 bg-white">
                      {sortedWallets.length === 0 ? (
                        <tr>
                          <td colSpan={8} className="px-4 py-14 text-center text-sm text-zinc-500">
                            Кошельки не найдены. Проверьте фильтры или дождитесь первых пополнений.
                          </td>
                        </tr>
                      ) : (
                        sortedWallets.map((wallet) => <WalletRow key={wallet.wallet_id} wallet={wallet} />)
                      )}
                    </tbody>
                  </table>
                </div>

                <div className="flex items-center justify-between border-t border-zinc-200 bg-zinc-50 px-4 py-3">
                  <p className="text-sm text-zinc-500">
                    Страница {page} • Показано {sortedWallets.length} кошельков
                  </p>
                  <div className="flex items-center gap-2">
                    <Link
                      href={page > 1 ? prevHref : "#"}
                      className={`rounded-md border px-3 py-1 text-sm ${
                        page > 1
                          ? "border-zinc-300 text-zinc-700 hover:bg-white"
                          : "pointer-events-none border-zinc-200 text-zinc-400"
                      }`}
                    >
                      ← Назад
                    </Link>
                    <Link
                      href={hasMore ? nextHref : "#"}
                      className={`rounded-md border px-3 py-1 text-sm ${
                        hasMore
                          ? "border-zinc-300 text-zinc-700 hover:bg-white"
                          : "pointer-events-none border-zinc-200 text-zinc-400"
                      }`}
                    >
                      Вперёд →
                    </Link>
                  </div>
                </div>
          </section>
        </>
      )}
    </div>
  );
}

function StatsGrid({ stats }: { stats: OwnerWalletsStats | null }) {
  const safeStats: OwnerWalletsStats = stats || {
    total_wallets: 0,
    total_balance_credits: 0,
    total_lifetime_topup_credits: 0,
    total_transactions: 0,
    total_orders: 0,
    total_revenue_credits: 0,
    avg_wallet_balance: 0,
    active_wallets_30d: 0,
    total_topup_credits: 0,
    total_spent_credits: 0,
    total_refund_credits: 0,
    net_wallet_change_credits: 0,
  };

  return (
    <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
      <StatCard label="Кошельков" value={String(safeStats.total_wallets)} tone="neutral" />
      <StatCard label="Общий баланс" value={formatCredits(safeStats.total_balance_credits)} tone="blue" />
      <StatCard label="Пополнено" value={formatCredits(safeStats.total_topup_credits)} tone="green" />
      <StatCard label="Списано" value={formatCredits(safeStats.total_spent_credits)} tone="red" />
      <StatCard label="Возвраты" value={formatCredits(safeStats.total_refund_credits)} tone="violet" />
      <StatCard
        label="Net поток"
        value={formatCredits(safeStats.net_wallet_change_credits)}
        tone={safeStats.net_wallet_change_credits >= 0 ? "green" : "red"}
      />
      <StatCard label="Заказы" value={String(safeStats.total_orders)} tone="neutral" />
      <StatCard label="Активные 30д" value={String(safeStats.active_wallets_30d)} tone="neutral" />
    </section>
  );
}

function StatCard({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: "neutral" | "blue" | "green" | "red" | "violet";
}) {
  const toneClasses = {
    neutral: "border-zinc-200 bg-white text-zinc-900",
    blue: "border-blue-200 bg-blue-50 text-blue-900",
    green: "border-emerald-200 bg-emerald-50 text-emerald-900",
    red: "border-red-200 bg-red-50 text-red-900",
    violet: "border-violet-200 bg-violet-50 text-violet-900",
  };

  return (
    <div className={`rounded-lg border p-4 ${toneClasses[tone]}`}>
      <p className="text-xs font-medium text-zinc-500">{label}</p>
      <p className="mt-2 text-2xl font-bold">{value}</p>
    </div>
  );
}

function WalletRow({ wallet }: { wallet: AdminWallet }) {
  const activity = activityTimestamp(wallet);
  const activityDate = activity ? new Date(activity) : null;
  const topups = toInt(wallet.total_topup_credits);
  const spent = toInt(wallet.total_spent_credits);

  return (
    <tr className="hover:bg-zinc-50">
      <td className="px-4 py-3">
        <div className="flex flex-col">
          <span className="text-sm font-medium text-zinc-900">{wallet.user_full_name || "—"}</span>
          <span className="text-xs text-zinc-500">{wallet.user_email || "email не указан"}</span>
          <span className="text-xs font-mono text-zinc-400">{wallet.user_phone || "—"}</span>
        </div>
      </td>

      <td className="px-4 py-3">
        <div className="flex flex-col gap-1">
          <span className="text-sm text-zinc-900">{wallet.cafe_name || "—"}</span>
          <WalletTypeBadge type={wallet.wallet_type} />
        </div>
      </td>

      <td className="px-4 py-3 text-right text-sm font-semibold text-zinc-900">
        {formatCredits(toInt(wallet.balance_credits))}
      </td>

      <td className="px-4 py-3 text-right text-sm font-medium text-emerald-700">
        {formatCredits(topups)}
      </td>

      <td className="px-4 py-3 text-right text-sm font-medium text-red-700">
        {formatCredits(spent)}
      </td>

      <td className="px-4 py-3">
        {activityDate ? (
          <div className="flex flex-col text-sm">
            <span className="text-zinc-700">{activityDate.toLocaleDateString("ru-RU")}</span>
            <span className="text-xs text-zinc-500">
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

      <td className="px-4 py-3">
        <div className="flex items-center justify-center gap-2 text-xs text-zinc-600">
          <span>Тр: {toInt(wallet.total_transactions)}</span>
          <span>•</span>
          <span>Пл: {toInt(wallet.total_payments)}</span>
          <span>•</span>
          <span>Зак: {toInt(wallet.total_orders)}</span>
        </div>
      </td>

      <td className="px-4 py-3 text-right">
        <Link
          href={`/admin/owner/wallets/${wallet.wallet_id}`}
          className="inline-flex items-center gap-1 rounded-md border border-zinc-300 px-3 py-1.5 text-xs font-medium text-zinc-700 hover:border-zinc-400 hover:bg-zinc-50"
        >
          Детали
          <span>→</span>
        </Link>
      </td>
    </tr>
  );
}

function WalletTypeBadge({ type }: { type: string }) {
  return (
    <span className="inline-flex w-fit items-center rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-700">
      {type === "cafe_wallet" ? "Cafe Wallet" : "CityPass"}
    </span>
  );
}
