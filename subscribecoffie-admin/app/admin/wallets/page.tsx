import Link from "next/link";

import { listWallets, getWalletsStats } from "../../../lib/supabase/queries/wallets";

export default async function WalletsPage() {
  let wallets: any[] = [];
  let stats: any = null;
  let error: string | null = null;

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

  // Group wallets by user
  const userWalletsMap = new Map<string, any[]>();
  const userProfilesMap = new Map<string, any>();
  
  (wallets || []).forEach((wallet: any) => {
    if (!userWalletsMap.has(wallet.user_id)) {
      userWalletsMap.set(wallet.user_id, []);
      userProfilesMap.set(wallet.user_id, wallet.profiles);
    }
    userWalletsMap.get(wallet.user_id)!.push(wallet);
  });

  const usersWithWallets = Array.from(userWalletsMap.entries()).map(([userId, wallets]) => ({
    userId,
    profile: userProfilesMap.get(userId),
    wallets,
    totalBalance: wallets.reduce((sum, w) => sum + (w.balance_credits || 0), 0),
    totalLifetime: wallets.reduce((sum, w) => sum + (w.lifetime_top_up_credits || 0), 0),
  }));

  return (
    <section className="space-y-6">
      {/* Header */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-semibold">Кошельки пользователей</h2>
          <span className="text-sm text-emerald-600">Supabase: OK</span>
        </div>

        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Всего кошельков</p>
              <p className="text-2xl font-semibold mt-1">
                {stats.total_wallets || 0}
              </p>
              <p className="text-xs text-zinc-400 mt-1">
                CityPass: {stats.citypass_count || 0} | Cafe: {stats.cafe_wallet_count || 0}
              </p>
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Пользователей</p>
              <p className="text-2xl font-semibold mt-1">
                {usersWithWallets.length}
              </p>
              <p className="text-xs text-zinc-400 mt-1">
                Средн. {usersWithWallets.length > 0 ? (stats.total_wallets / usersWithWallets.length).toFixed(1) : 0} кош./польз.
              </p>
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Общий баланс</p>
              <p className="text-2xl font-semibold mt-1">
                {Math.round(stats.total_balance || 0)} кр.
              </p>
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Средний баланс</p>
              <p className="text-2xl font-semibold mt-1">
                {Math.round(stats.avg_balance || 0)} кр.
              </p>
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
