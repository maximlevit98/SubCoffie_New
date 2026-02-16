import { redirect } from 'next/navigation';

import LegacyAdminLayout from '@/components/LegacyAdminLayout';
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
  description: string;
  payer: 'customer' | 'cafe' | 'platform';
  runtime: string;
  sampleBase: number;
};

const COMMISSION_META: Record<string, CommissionPolicyMeta> = {
  cafe_wallet_topup: {
    title: 'Cafe Wallet Top-up',
    description: 'Пополнение кошелька конкретной кофейни',
    payer: 'cafe',
    runtime: 'Применяется в mock_wallet_topup для cafe_wallet',
    sampleBase: 1000,
  },
  citypass_order_payment: {
    title: 'CityPass Order Payment',
    description: 'Комиссия на оплату заказа CityPass кошельком',
    payer: 'cafe',
    runtime: 'Применяется при order_payment (CityPass) через trigger',
    sampleBase: 500,
  },
  citypass_topup: {
    title: 'CityPass Top-up (Preview)',
    description: 'Для клиента должен быть 0% (не уменьшает зачисление)',
    payer: 'platform',
    runtime: 'Используется только для превью top-up в iOS',
    sampleBase: 1000,
  },
  direct_order: {
    title: 'Direct Order',
    description: 'Резерв для прямой оплаты заказа без кошелька',
    payer: 'customer',
    runtime: 'Пока не основной путь, держим как конфигурацию',
    sampleBase: 500,
  },
};

function payerLabel(payer: CommissionPolicyMeta['payer']): string {
  if (payer === 'cafe') return 'Плательщик: кофейня';
  if (payer === 'platform') return 'Плательщик: платформа';
  return 'Плательщик: клиент';
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

  return (
    <LegacyAdminLayout>
      <section className="space-y-6">
        <header className="space-y-2">
          <h2 className="text-2xl font-semibold text-zinc-900">Комиссии и бонусы</h2>
          <p className="text-sm text-zinc-600">
            Модель включена: клиент получает полный top-up, комиссия для Cafe Wallet и CityPass order транзакций начисляется кофейне.
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
              <h3 className="text-lg font-semibold text-zinc-900">Политики комиссий</h3>
              <p className="mt-1 text-sm text-zinc-600">
                Изменения применяются в backend RPC сразу после сохранения.
              </p>

              <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-2">
                {((commissionRows || []) as CommissionRow[]).map((row) => {
                  const meta = COMMISSION_META[row.operation_type] || {
                    title: row.operation_type,
                    description: 'Пользовательская конфигурация',
                    payer: 'customer' as const,
                    runtime: 'Использование зависит от backend flow',
                    sampleBase: 1000,
                  };

                  const sampleFee = calcFee(meta.sampleBase, row.commission_percent);

                  return (
                    <article key={row.id} className="rounded-lg border border-zinc-200 p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <h4 className="text-base font-semibold text-zinc-900">{meta.title}</h4>
                          <p className="mt-1 text-sm text-zinc-600">{meta.description}</p>
                        </div>
                        <span className={`rounded-full px-2 py-1 text-xs font-medium ${payerTone(meta.payer)}`}>
                          {payerLabel(meta.payer)}
                        </span>
                      </div>

                      <p className="mt-3 text-xs text-zinc-500">{meta.runtime}</p>

                      <div className="mt-3 rounded-md border border-zinc-200 bg-zinc-50 p-3 text-sm text-zinc-700">
                        Пример: база {meta.sampleBase.toLocaleString('ru-RU')} кр. → комиссия {sampleFee.toLocaleString('ru-RU')} кр.
                      </div>

                      <form action={updateCommissionPolicyAction} className="mt-4 flex items-end gap-2">
                        <input type="hidden" name="operation_type" value={row.operation_type} />
                        <label className="flex-1 text-xs text-zinc-600">
                          Ставка (%)
                          <input
                            name="commission_percent"
                            type="number"
                            step="0.01"
                            min="0"
                            max="100"
                            defaultValue={row.commission_percent}
                            className="mt-1 w-full rounded-md border border-zinc-300 px-3 py-2 text-sm"
                          />
                        </label>
                        <button
                          type="submit"
                          className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
                        >
                          Сохранить
                        </button>
                      </form>
                    </article>
                  );
                })}
              </div>
            </section>

            <section className="rounded-lg border border-zinc-200 bg-white p-5">
              <h3 className="text-lg font-semibold text-zinc-900">Бонусы (cashback по уровням)</h3>
              <p className="mt-1 text-sm text-zinc-600">
                Управление бонусной нагрузкой через проценты cashback в уровнях лояльности.
              </p>

              <div className="mt-4 overflow-x-auto">
                <table className="min-w-full divide-y divide-zinc-200">
                  <thead className="bg-zinc-50">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase text-zinc-500">Уровень</th>
                      <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">Порог, points</th>
                      <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">Cashback</th>
                      <th className="px-4 py-3 text-right text-xs font-medium uppercase text-zinc-500">Обновить</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-100 bg-white">
                    {((loyaltyLevels || []) as LoyaltyLevelRow[]).map((level) => (
                      <tr key={level.id}>
                        <td className="px-4 py-3 text-sm font-medium text-zinc-900">{level.level_name}</td>
                        <td className="px-4 py-3 text-right text-sm text-zinc-700">
                          {level.points_required.toLocaleString('ru-RU')}
                        </td>
                        <td className="px-4 py-3">
                          <form action={updateLoyaltyBonusAction} className="flex items-center justify-end gap-2">
                            <input type="hidden" name="level_id" value={level.id} />
                            <input
                              name="cashback_percent"
                              type="number"
                              step="0.01"
                              min="0"
                              max="100"
                              defaultValue={level.cashback_percent}
                              className="w-24 rounded-md border border-zinc-300 px-2 py-1 text-right text-sm"
                            />
                            <span className="text-sm text-zinc-500">%</span>
                            <button
                              type="submit"
                              className="rounded-md border border-zinc-300 px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
                            >
                              Сохранить
                            </button>
                          </form>
                        </td>
                        <td className="px-4 py-3 text-right text-xs text-zinc-500">
                          {level.updated_at ? new Date(level.updated_at).toLocaleString('ru-RU') : '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          </>
        )}
      </section>
    </LegacyAdminLayout>
  );
}
