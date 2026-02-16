import Link from "next/link";

import type {
  FinancialAnomaly,
  FinancialControlMetrics,
} from "@/lib/supabase/queries/financial-control";

type CafeFilterOption = {
  id: string;
  name: string | null;
};

type FinancialControlTowerViewProps = {
  title: string;
  subtitle: string;
  scopeBadge: string;
  basePath: string;
  walletsPath: string;
  rangeDays: number;
  cafeFilter: string;
  cafes: CafeFilterOption[];
  metrics: FinancialControlMetrics | null;
  anomalies: FinancialAnomaly[];
  error: string | null;
};

function formatCredits(value: number): string {
  return `${value.toLocaleString("ru-RU")} кр.`;
}

function toDateRange(days: number) {
  const now = new Date();
  const from = new Date(now);
  from.setDate(now.getDate() - days);
  return {
    from: from.toLocaleDateString("ru-RU"),
    to: now.toLocaleDateString("ru-RU"),
  };
}

export function FinancialControlTowerView({
  title,
  subtitle,
  scopeBadge,
  basePath,
  walletsPath,
  rangeDays,
  cafeFilter,
  cafes,
  metrics,
  anomalies,
  error,
}: FinancialControlTowerViewProps) {
  const dateRange = toDateRange(rangeDays);

  return (
    <div className="space-y-6">
      <header className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-zinc-900">{title}</h1>
          <p className="mt-1 text-sm text-zinc-600">{subtitle}</p>
          <p className="mt-1 text-xs text-zinc-500">
            Период: {dateRange.from} - {dateRange.to}
          </p>
        </div>
        <span className="rounded-md bg-blue-100 px-3 py-1 text-xs font-medium text-blue-700">
          {scopeBadge}
        </span>
      </header>

      <section className="rounded-lg border border-zinc-200 bg-white p-4">
        <form className="grid grid-cols-1 gap-3 md:grid-cols-12" method="get">
          <div className="md:col-span-3">
            <label htmlFor="days" className="mb-1 block text-xs font-medium text-zinc-600">
              Период
            </label>
            <select
              id="days"
              name="days"
              defaultValue={String(rangeDays)}
              className="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
            >
              <option value="1">За сегодня</option>
              <option value="7">7 дней</option>
              <option value="30">30 дней</option>
              <option value="90">90 дней</option>
            </select>
          </div>

          <div className="md:col-span-5">
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
              {cafes.map((cafe) => (
                <option key={cafe.id} value={cafe.id}>
                  {cafe.name || cafe.id}
                </option>
              ))}
            </select>
          </div>

          <div className="md:col-span-4 flex items-end justify-end gap-2">
            <Link
              href={basePath}
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
        </form>
      </section>

      {error ? (
        <section className="rounded-lg border border-red-200 bg-red-50 p-4">
          <p className="text-sm font-medium text-red-800">Не удалось загрузить контрольные метрики</p>
          <p className="mt-1 text-sm text-red-700">{error}</p>
        </section>
      ) : (
        <>
          <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
            <MetricCard
              label="Пополнения (completed)"
              value={formatCredits(metrics?.topup_completed_credits || 0)}
              hint={`${metrics?.topup_completed_count || 0} транзакций`}
              tone="green"
            />
            <MetricCard
              label="Списания на заказы"
              value={formatCredits(metrics?.order_payment_completed_credits || 0)}
              hint={`${metrics?.order_payment_completed_count || 0} транзакций`}
              tone="red"
            />
            <MetricCard
              label="Возвраты"
              value={formatCredits(metrics?.refund_completed_credits || 0)}
              hint={`${metrics?.refund_completed_count || 0} транзакций`}
              tone="violet"
            />
            <MetricCard
              label="Комиссия платформы"
              value={formatCredits(metrics?.platform_commission_credits || 0)}
              hint="Сумма по completed платежам"
              tone="neutral"
            />
            <MetricCard
              label="Снимок баланса кошельков"
              value={formatCredits(metrics?.wallet_balance_snapshot_credits || 0)}
              hint="Текущее состояние"
              tone="blue"
            />
            <MetricCard
              label="Платежи в ожидании"
              value={formatCredits(metrics?.pending_credits || 0)}
              hint={`Failed: ${formatCredits(metrics?.failed_credits || 0)}`}
              tone="amber"
            />
            <MetricCard
              label="Дельта кошельков (ledger)"
              value={formatCredits(metrics?.wallet_ledger_delta_credits || 0)}
              hint={`Ожидаемая: ${formatCredits(metrics?.expected_wallet_delta_credits || 0)}`}
              tone="neutral"
            />
            <MetricCard
              label="Reconciliation delta"
              value={formatCredits(metrics?.discrepancy_credits || 0)}
              hint={
                (metrics?.discrepancy_credits || 0) === 0
                  ? "Расхождений не найдено"
                  : "Требуется сверка"
              }
              tone={(metrics?.discrepancy_credits || 0) === 0 ? "green" : "red"}
            />
          </section>

          <section className="rounded-lg border border-zinc-200 bg-white p-4">
            <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
              <h2 className="text-lg font-semibold text-zinc-900">Заказы и покрытие платежами</h2>
              <Link
                href={walletsPath}
                className="text-sm font-medium text-blue-600 hover:text-blue-700"
              >
                Открыть кошельки →
              </Link>
            </div>
            <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-3">
              <InlineMetric
                label="Всего заказов"
                value={String(metrics?.orders_count || 0)}
              />
              <InlineMetric
                label="Завершённых"
                value={String(metrics?.completed_orders_count || 0)}
              />
              <InlineMetric
                label="Оплачено кредитами"
                value={formatCredits(metrics?.orders_paid_credits || 0)}
              />
            </div>
          </section>

          <section className="rounded-lg border border-zinc-200 bg-white">
            <div className="border-b border-zinc-200 px-4 py-3">
              <h2 className="text-lg font-semibold text-zinc-900">Anomaly feed</h2>
              <p className="text-xs text-zinc-500">
                Автоматические сигналы по расхождениям, пропущенным связям и отрицательным балансам
              </p>
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-zinc-200">
                <thead className="bg-zinc-50">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Серьёзность</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Тип</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Сообщение</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Сумма</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Время</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100 bg-white">
                  {anomalies.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-4 py-10 text-center text-sm text-zinc-500">
                        За выбранный период аномалии не обнаружены.
                      </td>
                    </tr>
                  ) : (
                    anomalies.map((anomaly) => (
                      <tr key={anomaly.anomaly_key} className="align-top hover:bg-zinc-50">
                        <td className="px-4 py-3">
                          <SeverityBadge severity={anomaly.severity} />
                        </td>
                        <td className="px-4 py-3 text-sm font-medium text-zinc-800">
                          {anomaly.anomaly_type}
                        </td>
                        <td className="px-4 py-3 text-sm text-zinc-700">
                          <p>{anomaly.message}</p>
                          {(anomaly.wallet_id || anomaly.order_id) && (
                            <p className="mt-1 text-xs font-mono text-zinc-500">
                              {anomaly.wallet_id ? `wallet=${anomaly.wallet_id}` : ""}
                              {anomaly.wallet_id && anomaly.order_id ? " • " : ""}
                              {anomaly.order_id ? `order=${anomaly.order_id}` : ""}
                            </p>
                          )}
                        </td>
                        <td className="px-4 py-3 text-sm font-semibold text-zinc-800">
                          {formatCredits(anomaly.amount_credits || 0)}
                        </td>
                        <td className="px-4 py-3 text-sm text-zinc-600">
                          {new Date(anomaly.detected_at).toLocaleString("ru-RU")}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </div>
  );
}

function MetricCard({
  label,
  value,
  hint,
  tone,
}: {
  label: string;
  value: string;
  hint: string;
  tone: "neutral" | "blue" | "green" | "red" | "amber" | "violet";
}) {
  const tones = {
    neutral: "border-zinc-200 bg-white text-zinc-900",
    blue: "border-blue-200 bg-blue-50 text-blue-900",
    green: "border-emerald-200 bg-emerald-50 text-emerald-900",
    red: "border-red-200 bg-red-50 text-red-900",
    amber: "border-amber-200 bg-amber-50 text-amber-900",
    violet: "border-violet-200 bg-violet-50 text-violet-900",
  };

  return (
    <div className={`rounded-lg border p-4 ${tones[tone]}`}>
      <p className="text-xs font-medium text-zinc-500">{label}</p>
      <p className="mt-2 text-2xl font-bold">{value}</p>
      <p className="mt-2 text-xs text-zinc-500">{hint}</p>
    </div>
  );
}

function InlineMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-3">
      <p className="text-xs text-zinc-500">{label}</p>
      <p className="mt-1 text-lg font-semibold text-zinc-900">{value}</p>
    </div>
  );
}

function SeverityBadge({ severity }: { severity: FinancialAnomaly["severity"] }) {
  const label =
    severity === "critical"
      ? "Critical"
      : severity === "high"
        ? "High"
        : severity === "medium"
          ? "Medium"
          : "Low";

  const styles =
    severity === "critical"
      ? "bg-red-100 text-red-800"
      : severity === "high"
        ? "bg-orange-100 text-orange-800"
        : severity === "medium"
          ? "bg-amber-100 text-amber-800"
          : "bg-zinc-200 text-zinc-700";

  return (
    <span className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${styles}`}>
      {label}
    </span>
  );
}
