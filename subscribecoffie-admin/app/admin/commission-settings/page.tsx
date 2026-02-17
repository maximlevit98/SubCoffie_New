import { redirect } from 'next/navigation';

import { getUserRole } from '@/lib/supabase/roles';
import { createServerClient } from '@/lib/supabase/server';

import {
  updateCommissionPolicyAction,
  updateLoyaltyBonusAction,
} from './actions';

type CommissionRow = {
  id: string;
  operation_type: string;
  commission_percent: number;
  active: boolean;
  updated_at: string | null;
};

type LoyaltyLevelRow = {
  id: string;
  level_name: string;
  level_order: number;
  points_required: number;
  cashback_percent: number;
  updated_at: string | null;
};

type CommissionPolicyMeta = {
  title: string;
  payer: 'customer' | 'cafe' | 'platform';
  customerEffect: string;
  applyMoment: string;
  note: string;
  sampleBase: number;
};

const POLICY_META: Record<string, CommissionPolicyMeta> = {
  cafe_wallet_topup: {
    title: 'Пополнение Cafe Wallet',
    payer: 'cafe',
    customerEffect: 'Клиенту зачисляется 100% суммы пополнения',
    applyMoment: 'Во время top-up (mock_wallet_topup)',
    note: 'Комиссия уходит в учёт кофейни, а не списывается с клиента',
    sampleBase: 1000,
  },
  citypass_order_payment: {
    title: 'Оплата заказа CityPass',
    payer: 'cafe',
    customerEffect: 'С клиента списывается сумма заказа без доп. удержаний',
    applyMoment: 'На транзакции order_payment (trigger)',
    note: 'Комиссия начисляется кофейне по факту оплаты заказа',
    sampleBase: 500,
  },
  citypass_topup: {
    title: 'Пополнение CityPass',
    payer: 'cafe',
    customerEffect: 'Клиенту зачисляется 100% суммы пополнения',
    applyMoment: 'На транзакции top_up (CityPass)',
    note: 'Комиссия по пополнению CityPass выставляется кофейне',
    sampleBase: 1000,
  },
  direct_order: {
    title: 'Прямая оплата заказа',
    payer: 'customer',
    customerEffect: 'Резервная политика для сценариев без кошелька',
    applyMoment: 'Только если включён direct_order flow',
    note: 'Оставлено для совместимости с legacy сценариями',
    sampleBase: 500,
  },
};

const POLICY_ORDER = [
  'cafe_wallet_topup',
  'citypass_order_payment',
  'citypass_topup',
  'direct_order',
];

function payerLabel(payer: CommissionPolicyMeta['payer']): string {
  if (payer === 'cafe') return 'Кофейня';
  if (payer === 'platform') return 'Платформа';
  return 'Клиент';
}

function payerTone(payer: CommissionPolicyMeta['payer']): string {
  if (payer === 'cafe') return 'bg-emerald-100 text-emerald-800';
  if (payer === 'platform') return 'bg-blue-100 text-blue-800';
  return 'bg-zinc-100 text-zinc-700';
}

function calcFee(base: number, percent: number): number {
  return Math.floor((base * percent) / 100);
}

export default async function CommissionSettingsPage() {
  const { role, userId } = await getUserRole();

  if (!userId) {
    redirect('/login');
  }

  if (role !== 'admin') {
    redirect('/admin/owner/dashboard');
  }

  const supabase = await createServerClient();

  const [{ data: commissionRows, error: commissionError }, { data: loyaltyLevels, error: loyaltyError }] =
    await Promise.all([
      supabase
        .from('commission_config')
        .select('id, operation_type, commission_percent, active, updated_at')
        .order('operation_type', { ascending: true }),
      supabase
        .from('loyalty_levels')
        .select('id, level_name, level_order, points_required, cashback_percent, updated_at')
        .order('level_order', { ascending: true }),
    ]);

  const error = commissionError?.message || loyaltyError?.message || null;

  const policiesByType = new Map(
    ((commissionRows || []) as CommissionRow[]).map((row) => [row.operation_type, row])
  );

  const orderedPolicies: CommissionRow[] = POLICY_ORDER
    .map((key) => policiesByType.get(key))
    .filter((row): row is CommissionRow => Boolean(row));

  for (const row of (commissionRows || []) as CommissionRow[]) {
    if (!POLICY_ORDER.includes(row.operation_type)) {
      orderedPolicies.push(row);
    }
  }

  return (
    <section className="space-y-6">
      <header className="space-y-2">
        <h2 className="text-2xl font-semibold text-zinc-900">Commission Settings</h2>
        <p className="text-sm text-zinc-600">
          Центр управления комиссиями и бонусами. Базовая модель: клиент получает полный top-up, комиссия по нужным сценариям начисляется кофейне.
        </p>
      </header>

      {error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4">
          <p className="text-sm font-medium text-red-800">Не удалось загрузить настройки</p>
          <p className="mt-1 text-sm text-red-700">{error}</p>
        </div>
      ) : (
        <>
          <section className="rounded-lg border border-zinc-200 bg-white p-5">
            <h3 className="text-lg font-semibold text-zinc-900">Как работает модель</h3>
            <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-3">
              <ScenarioCard
                title="1. Cafe Wallet top-up"
                payer="Кофейня"
                result="Клиенту зачисляется полная сумма пополнения"
                details="Комиссия пишется в payment_transactions как fee_payer = cafe"
              />
              <ScenarioCard
                title="2. CityPass top-up"
                payer="Кофейня"
                result="Клиенту зачисляется полная сумма"
                details="Комиссия начисляется на транзакции пополнения CityPass"
              />
              <ScenarioCard
                title="3. CityPass order payment"
                payer="Кофейня"
                result="С клиента списывается только сумма заказа"
                details="Комиссия начисляется на order_payment и привязывается к cafe_id"
              />
            </div>
          </section>

          <section className="rounded-lg border border-zinc-200 bg-white p-5">
            <h3 className="text-lg font-semibold text-zinc-900">Политики комиссий</h3>
            <p className="mt-1 text-sm text-zinc-600">
              Каждая строка показывает: кто платит, где применяется и как влияет на клиента.
            </p>
            <p className="mt-1 text-xs text-zinc-500">
              Если политика выключена (`active = false`), она не должна участвовать в расчётах backend flow.
            </p>

            <div className="mt-4 overflow-x-auto">
              <table className="min-w-full divide-y divide-zinc-200">
                <thead className="bg-zinc-50">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Сценарий</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Плательщик</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Статус</th>
                    <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">Ставка</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Эффект для клиента</th>
                    <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Применение</th>
                    <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">Изменить</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100 bg-white">
                  {orderedPolicies.map((row) => {
                    const meta = POLICY_META[row.operation_type] || {
                      title: row.operation_type,
                      payer: 'customer' as const,
                      customerEffect: 'Зависит от flow',
                      applyMoment: 'Зависит от backend реализации',
                      note: 'Без описания',
                      sampleBase: 1000,
                    };

                    const sampleFee = calcFee(meta.sampleBase, row.commission_percent);

                    return (
                      <tr key={row.id} className="align-top">
                        <td className="px-4 py-3">
                          <p className="text-sm font-semibold text-zinc-900">{meta.title}</p>
                          <p className="mt-1 text-xs text-zinc-500">{row.operation_type}</p>
                          <p className="mt-2 text-xs text-zinc-500">{meta.note}</p>
                        </td>
                        <td className="px-4 py-3">
                          <span className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${payerTone(meta.payer)}`}>
                            {payerLabel(meta.payer)}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span
                            className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                              row.active
                                ? 'bg-emerald-100 text-emerald-800'
                                : 'bg-zinc-100 text-zinc-600'
                            }`}
                          >
                            {row.active ? 'Включено' : 'Выключено'}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <p className="text-sm font-semibold text-zinc-900">{row.commission_percent}%</p>
                          <p className="mt-1 text-xs text-zinc-500">
                            пример: {meta.sampleBase.toLocaleString('ru-RU')} → {sampleFee.toLocaleString('ru-RU')} кр.
                          </p>
                        </td>
                        <td className="px-4 py-3 text-sm text-zinc-700">{meta.customerEffect}</td>
                        <td className="px-4 py-3 text-sm text-zinc-700">{meta.applyMoment}</td>
                        <td className="px-4 py-3">
                          <form action={updateCommissionPolicyAction} className="flex items-center justify-end gap-2">
                            <input type="hidden" name="operation_type" value={row.operation_type} />
                            <input
                              name="commission_percent"
                              type="number"
                              step="0.01"
                              min="0"
                              max="100"
                              defaultValue={row.commission_percent}
                              disabled={!row.active}
                              className="w-24 rounded-md border border-zinc-300 px-2 py-1 text-right text-sm disabled:cursor-not-allowed disabled:bg-zinc-100 disabled:text-zinc-400"
                            />
                            <span className="text-sm text-zinc-500">%</span>
                            <button
                              type="submit"
                              disabled={!row.active}
                              className="rounded-md bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-zinc-300 disabled:text-zinc-600"
                            >
                              Сохранить
                            </button>
                          </form>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </section>

          <section className="rounded-lg border border-zinc-200 bg-white p-5">
            <h3 className="text-lg font-semibold text-zinc-900">Бонусы и cashback</h3>
            <p className="mt-1 text-sm text-zinc-600">
              Настройка бонусной нагрузки по уровням лояльности. Значения влияют на будущие начисления.
            </p>

            <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
              {((loyaltyLevels || []) as LoyaltyLevelRow[]).map((level) => {
                const sampleOrder = 300;
                const sampleCashback = calcFee(sampleOrder, level.cashback_percent);

                return (
                  <article key={level.id} className="rounded-lg border border-zinc-200 p-4">
                    <div className="flex items-center justify-between">
                      <h4 className="text-base font-semibold text-zinc-900">{level.level_name}</h4>
                      <span className="text-xs text-zinc-500">от {level.points_required.toLocaleString('ru-RU')} pts</span>
                    </div>

                    <p className="mt-2 text-xs text-zinc-500">
                      Пример: заказ {sampleOrder} кр. → cashback {sampleCashback} кр.
                    </p>

                    <form action={updateLoyaltyBonusAction} className="mt-4 flex items-end gap-2">
                      <input type="hidden" name="level_id" value={level.id} />
                      <label className="flex-1 text-xs text-zinc-600">
                        Cashback (%)
                        <input
                          name="cashback_percent"
                          type="number"
                          step="0.01"
                          min="0"
                          max="100"
                          defaultValue={level.cashback_percent}
                          className="mt-1 w-full rounded-md border border-zinc-300 px-3 py-2 text-sm"
                        />
                      </label>
                      <button
                        type="submit"
                        className="rounded-md border border-zinc-300 px-3 py-2 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
                      >
                        Сохранить
                      </button>
                    </form>

                    <p className="mt-2 text-xs text-zinc-500">
                      Обновлено: {level.updated_at ? new Date(level.updated_at).toLocaleString('ru-RU') : '—'}
                    </p>
                  </article>
                );
              })}
            </div>
          </section>
        </>
      )}
    </section>
  );
}

function ScenarioCard({
  title,
  payer,
  result,
  details,
}: {
  title: string;
  payer: string;
  result: string;
  details: string;
}) {
  return (
    <article className="rounded-lg border border-zinc-200 bg-zinc-50 p-4">
      <h4 className="text-sm font-semibold text-zinc-900">{title}</h4>
      <p className="mt-2 text-sm text-zinc-700">
        <span className="font-medium">Плательщик:</span> {payer}
      </p>
      <p className="mt-1 text-sm text-zinc-700">
        <span className="font-medium">Результат:</span> {result}
      </p>
      <p className="mt-2 text-xs text-zinc-500">{details}</p>
    </article>
  );
}
