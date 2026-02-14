"use client";

type WalletStatsCardsProps = {
  stats: {
    total_wallets: number;
    total_balance: number;
    avg_balance: number;
    citypass_count: number;
    cafe_wallet_count: number;
  };
  filteredData?: {
    citypass_balance: number;
    cafe_wallet_balance: number;
  };
};

export function WalletStatsCards({ stats, filteredData }: WalletStatsCardsProps) {
  const citypassPercentage = Math.round(
    (stats.citypass_count / (stats.total_wallets || 1)) * 100
  );
  const cafePercentage = Math.round(
    (stats.cafe_wallet_count / (stats.total_wallets || 1)) * 100
  );

  const citypassBalance = filteredData
    ? filteredData.citypass_balance
    : stats.total_balance * (stats.citypass_count / (stats.total_wallets || 1));
  const cafeBalance = filteredData
    ? filteredData.cafe_wallet_balance
    : stats.total_balance * (stats.cafe_wallet_count / (stats.total_wallets || 1));

  return (
    <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
      {/* Total Wallets */}
      <div className="rounded-lg border border-zinc-200 bg-white p-4 shadow-sm">
        <p className="text-xs font-medium text-zinc-500 uppercase tracking-wide">
          Всего кошельков
        </p>
        <p className="text-3xl font-bold mt-2 text-zinc-900">
          {stats.total_wallets || 0}
        </p>
        <p className="text-xs text-zinc-400 mt-2">База данных</p>
      </div>

      {/* CityPass */}
      <div className="rounded-lg border-2 border-blue-200 bg-gradient-to-br from-blue-50 to-blue-100 p-4 shadow-sm">
        <div className="flex items-center justify-between mb-2">
          <p className="text-xs font-bold text-blue-700 uppercase tracking-wide">
            CityPass
          </p>
          <span className="text-xs font-semibold bg-blue-200 text-blue-800 px-2 py-0.5 rounded-full">
            {citypassPercentage}%
          </span>
        </div>
        <p className="text-3xl font-bold text-blue-700">
          {stats.citypass_count || 0}
        </p>
        <div className="mt-3 pt-3 border-t border-blue-200">
          <p className="text-xs text-blue-600">
            Баланс: {Math.round(citypassBalance)} кр.
          </p>
        </div>
      </div>

      {/* Cafe Wallet */}
      <div className="rounded-lg border-2 border-green-200 bg-gradient-to-br from-green-50 to-green-100 p-4 shadow-sm">
        <div className="flex items-center justify-between mb-2">
          <p className="text-xs font-bold text-green-700 uppercase tracking-wide">
            Cafe Wallet
          </p>
          <span className="text-xs font-semibold bg-green-200 text-green-800 px-2 py-0.5 rounded-full">
            {cafePercentage}%
          </span>
        </div>
        <p className="text-3xl font-bold text-green-700">
          {stats.cafe_wallet_count || 0}
        </p>
        <div className="mt-3 pt-3 border-t border-green-200">
          <p className="text-xs text-green-600">
            Баланс: {Math.round(cafeBalance)} кр.
          </p>
        </div>
      </div>

      {/* Total Balance */}
      <div className="rounded-lg border border-emerald-200 bg-gradient-to-br from-emerald-50 to-white p-4 shadow-sm">
        <p className="text-xs font-medium text-emerald-600 uppercase tracking-wide">
          Общий баланс
        </p>
        <p className="text-3xl font-bold mt-2 text-emerald-700">
          {Math.round(stats.total_balance || 0)}
        </p>
        <p className="text-xs text-emerald-600 mt-2">кредитов</p>
      </div>

      {/* Average Balance */}
      <div className="rounded-lg border border-purple-200 bg-gradient-to-br from-purple-50 to-white p-4 shadow-sm">
        <p className="text-xs font-medium text-purple-600 uppercase tracking-wide">
          Средний баланс
        </p>
        <p className="text-3xl font-bold mt-2 text-purple-700">
          {Math.round(stats.avg_balance || 0)}
        </p>
        <p className="text-xs text-purple-600 mt-2">кр. на кошелёк</p>
      </div>
    </div>
  );
}
