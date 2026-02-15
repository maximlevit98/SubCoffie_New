"use client";

import { type AdminWalletOverview } from "@/lib/supabase/queries/wallets";

type OwnerOverviewTabProps = {
  overview: AdminWalletOverview;
};

export function OwnerOverviewTab({ overview }: OwnerOverviewTabProps) {
  const lastActivity =
    overview.last_transaction_at ||
    overview.last_payment_at ||
    overview.last_order_at;

  return (
    <div className="space-y-6">
      {/* Wallet Info Card */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="mb-4 text-lg font-semibold">Информация о кошельке</h3>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
          {/* Left column */}
          <div className="space-y-4">
            <InfoRow label="Тип кошелька">
              <WalletTypeBadge type={overview.wallet_type} />
            </InfoRow>

            {overview.cafe_name && (
              <InfoRow label="Кофейня">
                <span className="text-sm text-zinc-900">
                  {overview.cafe_name}
                </span>
                {overview.cafe_address && (
                  <span className="mt-0.5 block text-xs text-zinc-500">
                    {overview.cafe_address}
                  </span>
                )}
              </InfoRow>
            )}

            {overview.network_name && (
              <InfoRow label="Сеть">
                <span className="text-sm text-zinc-900">
                  {overview.network_name}
                </span>
              </InfoRow>
            )}

            <InfoRow label="ID кошелька">
              <span className="text-xs font-mono text-zinc-600">
                {overview.wallet_id}
              </span>
            </InfoRow>

            <InfoRow label="Создан">
              <span className="text-sm text-zinc-900">
                {new Date(overview.created_at).toLocaleString("ru-RU")}
              </span>
            </InfoRow>

            <InfoRow label="Обновлён">
              <span className="text-sm text-zinc-900">
                {new Date(overview.updated_at).toLocaleString("ru-RU")}
              </span>
            </InfoRow>
          </div>

          {/* Right column */}
          <div className="space-y-4">
            <InfoRow label="Клиент">
              <div className="flex flex-col gap-1">
                <span className="text-sm font-medium text-zinc-900">
                  {overview.user_full_name || "—"}
                </span>
                {overview.user_email && (
                  <span className="text-xs text-zinc-500">
                    ✉️ {overview.user_email}
                  </span>
                )}
                {overview.user_phone && (
                  <span className="font-mono text-xs text-zinc-500">
                    📱 {overview.user_phone}
                  </span>
                )}
              </div>
            </InfoRow>

            <InfoRow label="ID клиента">
              <span className="text-xs font-mono text-zinc-600">
                {overview.user_id}
              </span>
            </InfoRow>

            <InfoRow label="Зарегистрирован">
              <span className="text-sm text-zinc-900">
                {new Date(overview.user_registered_at).toLocaleDateString(
                  "ru-RU"
                )}
              </span>
            </InfoRow>

            {lastActivity && (
              <InfoRow label="Последняя активность">
                <span className="text-sm text-zinc-900">
                  {new Date(lastActivity).toLocaleString("ru-RU")}
                </span>
              </InfoRow>
            )}
          </div>
        </div>
      </div>

      {/* Balance Card */}
      <div className="rounded-lg border-2 border-blue-200 bg-gradient-to-br from-blue-50 to-white p-6">
        <h3 className="mb-4 text-lg font-semibold">Баланс</h3>
        <div className="mb-6 flex items-end gap-2">
          <span className="text-5xl font-bold text-blue-900">
            {overview.balance_credits}
          </span>
          <span className="mb-2 text-lg text-zinc-500">кредитов</span>
        </div>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div className="rounded-lg bg-white p-4">
            <p className="text-sm text-zinc-600">Пополнено за всё время</p>
            <p className="mt-1 text-2xl font-bold text-emerald-600">
              {overview.lifetime_top_up_credits}
            </p>
            <p className="text-xs text-zinc-500">кредитов</p>
          </div>

          <div className="rounded-lg bg-white p-4">
            <p className="text-sm text-zinc-600">Оборот</p>
            <p className="mt-1 text-2xl font-bold text-zinc-900">
              {overview.lifetime_top_up_credits - overview.balance_credits}
            </p>
            <p className="text-xs text-zinc-500">потрачено кредитов</p>
          </div>
        </div>
      </div>

      {/* Activity Stats */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="mb-4 text-lg font-semibold">Статистика активности</h3>
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          <StatCard
            icon="💳"
            label="Транзакций"
            value={overview.total_transactions}
            subValue={`${overview.total_topups} пополнений`}
          />
          <StatCard
            icon="💰"
            label="Платежей"
            value={overview.total_payments}
            subValue={
              overview.total_refunds > 0
                ? `${overview.total_refunds} возвратов`
                : undefined
            }
          />
          <StatCard
            icon="🛒"
            label="Заказов"
            value={overview.total_orders}
            subValue={`${overview.completed_orders} завершено`}
          />
          <StatCard
            icon="📊"
            label="Конверсия"
            value={
              overview.total_orders > 0
                ? `${Math.round((overview.completed_orders / overview.total_orders) * 100)}%`
                : "—"
            }
            subValue="успешных заказов"
          />
        </div>
      </div>
    </div>
  );
}

// Helper Components
function InfoRow({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs font-medium uppercase tracking-wide text-zinc-500">
        {label}
      </span>
      {children}
    </div>
  );
}

function WalletTypeBadge({ type }: { type: string }) {
  const isCityPass = type === "citypass";
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
        isCityPass
          ? "bg-blue-100 text-blue-700"
          : "bg-green-100 text-green-700"
      }`}
    >
      {isCityPass ? "CityPass" : "Cafe Wallet"}
    </span>
  );
}

function StatCard({
  icon,
  label,
  value,
  subValue,
}: {
  icon: string;
  label: string;
  value: string | number;
  subValue?: string;
}) {
  return (
    <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-4">
      <div className="mb-2 text-2xl">{icon}</div>
      <p className="text-sm text-zinc-600">{label}</p>
      <p className="mt-1 text-2xl font-bold text-zinc-900">{value}</p>
      {subValue && <p className="mt-1 text-xs text-zinc-500">{subValue}</p>}
    </div>
  );
}
