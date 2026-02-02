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
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Общий баланс</p>
              <p className="text-2xl font-semibold mt-1">
                {Math.round(stats.total_balance || 0)} кр.
              </p>
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Бонусы</p>
              <p className="text-2xl font-semibold mt-1">
                {Math.round(stats.total_bonus || 0)} кр.
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

      {/* Wallets Table */}
      <div className="overflow-x-auto rounded-lg border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Пользователь</th>
              <th className="px-4 py-3 font-medium">Телефон</th>
              <th className="px-4 py-3 font-medium">Баланс</th>
              <th className="px-4 py-3 font-medium">Бонусы</th>
              <th className="px-4 py-3 font-medium">Всего пополнено</th>
              <th className="px-4 py-3 font-medium">Создан</th>
              <th className="px-4 py-3 font-medium"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {!wallets || wallets.length === 0 ? (
              <tr>
                <td className="px-4 py-8 text-center text-zinc-500" colSpan={7}>
                  Кошельки не найдены
                </td>
              </tr>
            ) : (
              wallets.map((wallet) => (
                <tr key={wallet.id} className="text-zinc-700 hover:bg-zinc-50">
                  <td className="px-4 py-3">
                    {wallet.profiles?.full_name || "—"}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">
                    {wallet.profiles?.phone || "—"}
                  </td>
                  <td className="px-4 py-3">
                    <span className="font-semibold">
                      {wallet.balance || 0} кр.
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-emerald-600">
                      {wallet.bonus_balance || 0} кр.
                    </span>
                  </td>
                  <td className="px-4 py-3 text-zinc-500">
                    {wallet.lifetime_topup || 0} кр.
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-500">
                    {new Date(wallet.created_at).toLocaleDateString("ru-RU")}
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/admin/wallets/${wallet.user_id}`}
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
