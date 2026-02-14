import Link from "next/link";

import { listWallets, getWalletsStats } from "../../../lib/supabase/queries/wallets";
import { WalletsFilters } from "./WalletsFilters";
import { WalletStatsCards } from "./WalletStatsCards";

type WalletsPageProps = {
  searchParams: {
    type?: string;
    search?: string;
  };
};

export default async function WalletsPage({ searchParams }: WalletsPageProps) {
  let wallets: any[] | null = [];
  let stats: any = null;
  let error: string | null = null;
  
  const filterType = searchParams.type;
  const searchQuery = searchParams.search?.toLowerCase() || "";

  try {
    [{ data: wallets, error: error }, { data: stats }] = await Promise.all([
      listWallets(),
      getWalletsStats(),
    ]);
  } catch (e: any) {
    error = e.message;
  }

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошельки</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить кошельки: {error}
        </p>
      </section>
    );
  }

  // Group wallets by user and apply filters
  const userWalletsMap = new Map<string, any[]>();
  const userProfilesMap = new Map<string, any>();
  
  (wallets || []).forEach((wallet: any) => {
    // Apply wallet type filter
    if (filterType && wallet.wallet_type !== filterType) {
      return;
    }
    
    if (!userWalletsMap.has(wallet.user_id)) {
      userWalletsMap.set(wallet.user_id, []);
      userProfilesMap.set(wallet.user_id, wallet.profiles);
    }
    userWalletsMap.get(wallet.user_id)!.push(wallet);
  });

  let usersWithWallets = Array.from(userWalletsMap.entries()).map(([userId, wallets]) => ({
    userId,
    profile: userProfilesMap.get(userId),
    wallets,
    totalBalance: wallets.reduce((sum, w) => sum + (w.balance_credits || 0), 0),
    totalLifetime: wallets.reduce((sum, w) => sum + (w.lifetime_top_up_credits || 0), 0),
  }));
  
  // Apply search filter
  if (searchQuery) {
    usersWithWallets = usersWithWallets.filter((user) => {
      const fullName = user.profile?.full_name?.toLowerCase() || "";
      const phone = user.profile?.phone?.toLowerCase() || "";
      return fullName.includes(searchQuery) || phone.includes(searchQuery);
    });
  }
  
  // Calculate filtered stats
  const filteredWallets = usersWithWallets.flatMap((u) => u.wallets);
  const filteredStats = {
    total_users: usersWithWallets.length,
    total_wallets: filteredWallets.length,
    total_balance: filteredWallets.reduce((sum, w) => sum + (w.balance_credits || 0), 0),
    citypass_count: filteredWallets.filter(w => w.wallet_type === "citypass").length,
    cafe_wallet_count: filteredWallets.filter(w => w.wallet_type === "cafe_wallet").length,
    citypass_balance: filteredWallets
      .filter(w => w.wallet_type === "citypass")
      .reduce((sum, w) => sum + (w.balance_credits || 0), 0),
    cafe_wallet_balance: filteredWallets
      .filter(w => w.wallet_type === "cafe_wallet")
      .reduce((sum, w) => sum + (w.balance_credits || 0), 0),
  };

  return (
    <section className="space-y-6">
      {/* Header */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-semibold">Кошельки пользователей</h2>
          <span className="text-sm text-emerald-600">Supabase: OK</span>
        </div>

        {/* Global Stats (all data) */}
        {stats && (
          <WalletStatsCards stats={stats} />
        )}

        {/* Filters */}
        <WalletsFilters 
          currentType={filterType}
          currentSearch={searchQuery}
          totalResults={usersWithWallets.length}
        />
        
        {/* Filtered Stats */}
        {(filterType || searchQuery) && (
          <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 p-4">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-sm font-medium text-amber-800">
                📊 Результаты фильтрации
              </span>
              {filterType && (
                <span className="inline-block px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-700 rounded">
                  {filterType === "citypass" ? "CityPass" : "Cafe Wallet"}
                </span>
              )}
              {searchQuery && (
                <span className="inline-block px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-700 rounded">
                  Поиск: "{searchQuery}"
                </span>
              )}
            </div>
            <div className="grid grid-cols-4 gap-4 text-sm">
              <div>
                <span className="text-amber-600">Пользователей:</span>
                <span className="ml-2 font-semibold text-amber-900">
                  {filteredStats.total_users}
                </span>
              </div>
              <div>
                <span className="text-amber-600">Кошельков:</span>
                <span className="ml-2 font-semibold text-amber-900">
                  {filteredStats.total_wallets}
                </span>
              </div>
              <div>
                <span className="text-amber-600">Общий баланс:</span>
                <span className="ml-2 font-semibold text-amber-900">
                  {Math.round(filteredStats.total_balance)} кр.
                </span>
              </div>
              <div>
                <span className="text-amber-600">CP / Cafe:</span>
                <span className="ml-2 font-semibold text-amber-900">
                  {filteredStats.citypass_count} / {filteredStats.cafe_wallet_count}
                </span>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Users Table (grouped by user) */}
      <div className="overflow-x-auto rounded-lg border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Пользователь</th>
              <th className="px-4 py-3 font-medium">Телефон</th>
              <th className="px-4 py-3 font-medium">Кошельков</th>
              <th className="px-4 py-3 font-medium">Типы</th>
              <th className="px-4 py-3 font-medium">Общий баланс</th>
              <th className="px-4 py-3 font-medium">Всего пополнено</th>
              <th className="px-4 py-3 font-medium"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {!usersWithWallets || usersWithWallets.length === 0 ? (
              <tr>
                <td className="px-4 py-8 text-center text-zinc-500" colSpan={7}>
                  Кошельки не найдены
                </td>
              </tr>
            ) : (
              usersWithWallets.map((user) => (
                <tr key={user.userId} className="text-zinc-700 hover:bg-zinc-50">
                  <td className="px-4 py-3">
                    {user.profile?.full_name || "—"}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">
                    {user.profile?.phone || "—"}
                  </td>
                  <td className="px-4 py-3">
                    <span className="font-semibold">{user.wallets.length}</span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1">
                      {user.wallets.map((w: any) => (
                        <span
                          key={w.id}
                          className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${
                            w.wallet_type === "citypass"
                              ? "bg-blue-100 text-blue-700"
                              : "bg-green-100 text-green-700"
                          }`}
                        >
                          {w.wallet_type === "citypass" ? "CP" : "Cafe"}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className="font-semibold">
                      {user.totalBalance} кр.
                    </span>
                  </td>
                  <td className="px-4 py-3 text-zinc-500">
                    {user.totalLifetime} кр.
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/admin/wallets/${user.userId}`}
                      className="inline-flex items-center rounded border border-zinc-300 px-3 py-1 text-xs font-medium hover:bg-zinc-50"
                    >
                      Управление →
                    </Link>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
