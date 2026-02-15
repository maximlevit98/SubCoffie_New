"use client";

import { type AdminWalletOverview } from "../../../../lib/supabase/queries/wallets";

type OverviewTabProps = {
  overview: AdminWalletOverview;
};

export function OverviewTab({ overview }: OverviewTabProps) {
  const lastActivity = overview.last_transaction_at || overview.last_payment_at || overview.last_order_at;

  return (
    <div className="space-y-6">
      {/* Wallet Info Card */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">Информация о кошельке</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Left column */}
          <div className="space-y-4">
            <InfoRow label="Тип кошелька">
              <WalletTypeBadge type={overview.wallet_type} />
            </InfoRow>
            
            {overview.cafe_name && (
              <InfoRow label="Кафе">
                <span className="text-sm text-zinc-900">{overview.cafe_name}</span>
                {overview.cafe_address && (
                  <span className="text-xs text-zinc-500 block mt-0.5">
                    {overview.cafe_address}
                  </span>
                )}
              </InfoRow>
            )}
            
            {overview.network_name && (
              <InfoRow label="Сеть">
                <span className="text-sm text-zinc-900">{overview.network_name}</span>
              </InfoRow>
            )}
            
            <InfoRow label="ID кошелька">
              <span className="text-xs font-mono text-zinc-600">{overview.wallet_id}</span>
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
            <InfoRow label="Пользователь">
              <div className="flex flex-col gap-1">
                <span className="text-sm font-medium text-zinc-900">
                  {overview.user_full_name || "—"}
                </span>
                {overview.user_email && (
                  <span className="text-xs text-zinc-500">✉️ {overview.user_email}</span>
                )}
                {overview.user_phone && (
                  <span className="text-xs text-zinc-500 font-mono">📱 {overview.user_phone}</span>
                )}
              </div>
            </InfoRow>
            
            <InfoRow label="ID пользователя">
              <span className="text-xs font-mono text-zinc-600">{overview.user_id}</span>
            </InfoRow>
            
            <InfoRow label="Зарегистрирован">
              <span className="text-sm text-zinc-900">
                {new Date(overview.user_registered_at).toLocaleDateString("ru-RU")}
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
        <h3 className="text-lg font-semibold mb-4">Баланс</h3>
        <div className="flex items-end gap-2 mb-6">
          <span className="text-5xl font-bold text-blue-900">
            {overview.balance_credits}
          </span>
          <span className="text-2xl text-blue-600 mb-2">кредитов</span>
        </div>
        
        <div className="grid grid-cols-2 gap-4 pt-4 border-t border-blue-200">
          <div>
            <p className="text-xs text-zinc-500 mb-1">Всего пополнено</p>
            <p className="text-xl font-semibold text-emerald-600">
              {overview.lifetime_top_up_credits} кр.
            </p>
          </div>
          <div>
            <p className="text-xs text-zinc-500 mb-1">Средний чек</p>
            <p className="text-xl font-semibold text-zinc-700">
              {overview.avg_order_paid_credits} кр.
            </p>
          </div>
        </div>
      </div>

      {/* Financial Summary */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="text-lg font-semibold mb-4">Финансовая сводка</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          <FinanceCell
            label="Пополнено"
            value={overview.total_topup_credits}
            tone="emerald"
          />
          <FinanceCell
            label="Списано"
            value={overview.total_payment_credits}
            tone="red"
          />
          <FinanceCell
            label="Возвраты"
            value={overview.total_refund_credits}
            tone="violet"
          />
          <FinanceCell
            label="Корректировки"
            value={overview.total_adjustment_credits}
            tone={overview.total_adjustment_credits >= 0 ? "emerald" : "red"}
          />
          <FinanceCell
            label="Net поток"
            value={overview.net_wallet_change_credits}
            tone={overview.net_wallet_change_credits >= 0 ? "emerald" : "red"}
          />
        </div>
      </div>

      {/* Activity Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Транзакции"
          value={overview.total_transactions}
          icon="💳"
          breakdown={[
            { label: "Пополнения", value: overview.total_topups },
            { label: "Оплаты", value: overview.total_payments },
            { label: "Возвраты", value: overview.total_refunds },
          ]}
        />
        
        <StatCard
          label="Заказы"
          value={overview.total_orders}
          icon="🛒"
          breakdown={[
            { label: "Завершено", value: overview.completed_orders },
            { label: "Прочие", value: overview.total_orders - overview.completed_orders },
          ]}
        />
        
        <StatCard
          label="Платёжные транзакции"
          value={overview.total_payments}
          icon="💰"
        />
        
        <StatCard
          label="Возвраты"
          value={overview.total_refunds}
          icon="↩️"
        />
      </div>

      {/* Last Activity Timestamps */}
      {(overview.last_transaction_at || overview.last_payment_at || overview.last_order_at) && (
        <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-6">
          <h3 className="text-sm font-semibold text-zinc-700 mb-4">
            Временные метки активности
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {overview.last_transaction_at && (
              <div>
                <p className="text-xs text-zinc-500 mb-1">Последняя транзакция</p>
                <p className="text-sm text-zinc-900">
                  {new Date(overview.last_transaction_at).toLocaleString("ru-RU")}
                </p>
              </div>
            )}
            
            {overview.last_payment_at && (
              <div>
                <p className="text-xs text-zinc-500 mb-1">Последний платёж</p>
                <p className="text-sm text-zinc-900">
                  {new Date(overview.last_payment_at).toLocaleString("ru-RU")}
                </p>
              </div>
            )}
            
            {overview.last_order_at && (
              <div>
                <p className="text-xs text-zinc-500 mb-1">Последний заказ</p>
                <p className="text-sm text-zinc-900">
                  {new Date(overview.last_order_at).toLocaleString("ru-RU")}
                </p>
              </div>
            )}

            {overview.last_topup_at && (
              <div>
                <p className="text-xs text-zinc-500 mb-1">Последнее пополнение</p>
                <p className="text-sm text-zinc-900">
                  {new Date(overview.last_topup_at).toLocaleString("ru-RU")}
                </p>
              </div>
            )}

            {overview.last_refund_at && (
              <div>
                <p className="text-xs text-zinc-500 mb-1">Последний возврат</p>
                <p className="text-sm text-zinc-900">
                  {new Date(overview.last_refund_at).toLocaleString("ru-RU")}
                </p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// Helper components
function InfoRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-xs text-zinc-500 mb-1">{label}</p>
      {children}
    </div>
  );
}

function WalletTypeBadge({ type }: { type: string }) {
  const isCityPass = type === "citypass";
  return (
    <span
      className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${
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
  label,
  value,
  icon,
  breakdown,
}: {
  label: string;
  value: number;
  icon: string;
  breakdown?: Array<{ label: string; value: number }>;
}) {
  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-4">
      <div className="flex items-center justify-between mb-2">
        <span className="text-2xl">{icon}</span>
        <span className="text-2xl font-bold text-zinc-900">{value}</span>
      </div>
      <p className="text-xs text-zinc-500 mb-3">{label}</p>
      
      {breakdown && breakdown.length > 0 && (
        <div className="space-y-1 pt-3 border-t border-zinc-100">
          {breakdown.map((item) => (
            <div key={item.label} className="flex items-center justify-between text-xs">
              <span className="text-zinc-500">{item.label}</span>
              <span className="font-medium text-zinc-700">{item.value}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function FinanceCell({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: "emerald" | "red" | "violet";
}) {
  const styles = {
    emerald: "bg-emerald-50 text-emerald-700 border-emerald-200",
    red: "bg-red-50 text-red-700 border-red-200",
    violet: "bg-violet-50 text-violet-700 border-violet-200",
  };

  return (
    <div className={`rounded-md border px-3 py-3 ${styles[tone]}`}>
      <p className="text-xs opacity-80">{label}</p>
      <p className="text-lg font-semibold mt-1">{value} кр.</p>
    </div>
  );
}
