import { getCommissionConfig } from "../../../lib/supabase/queries/payments";
import CommissionForm from "./CommissionForm";

export default async function CommissionSettingsPage() {
  const { data: configs, error } = await getCommissionConfig();

  if (error) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Commission Settings</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить настройки комиссий: {error}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Commission Settings</h2>
        <span className="rounded-full bg-yellow-100 px-3 py-1 text-xs font-medium text-yellow-700">
          DEMO MODE
        </span>
      </div>

      <div className="rounded border border-blue-200 bg-blue-50 p-4">
        <p className="text-sm text-blue-800">
          Configure commission rates for different operation types. These rates
          are used for calculating platform revenue from mock payments.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
        {configs?.map((config) => {
          const labels: Record<string, { title: string; description: string }> =
            {
              citypass_topup: {
                title: "CityPass Top-up",
                description:
                  "Universal wallet top-up commission (works at all cafes)",
              },
              cafe_wallet_topup: {
                title: "Cafe Wallet Top-up",
                description:
                  "Cafe-specific wallet commission (lower rate for loyalty)",
              },
              direct_order: {
                title: "Direct Order Payment",
                description:
                  "Commission for orders paid directly without wallet",
              },
            };

          const label = labels[config.operation_type] || {
            title: config.operation_type,
            description: "",
          };

          return (
            <div
              key={config.id}
              className="rounded-lg border border-zinc-200 bg-white p-6"
            >
              <h3 className="mb-2 text-lg font-semibold text-zinc-900">
                {label.title}
              </h3>
              <p className="mb-4 text-sm text-zinc-600">{label.description}</p>

              <div className="mb-4">
                <div className="text-3xl font-bold text-zinc-900">
                  {config.commission_percent}%
                </div>
                <div className="text-xs text-zinc-500">Current Rate</div>
              </div>

              <CommissionForm
                operationType={config.operation_type}
                currentRate={config.commission_percent}
              />
            </div>
          );
        })}
      </div>

      <div className="rounded border border-yellow-200 bg-yellow-50 p-4">
        <p className="text-sm text-yellow-800">
          <strong>Note:</strong> Commission calculations are fully functional in
          demo mode. Changes here affect mock payment processing immediately.
        </p>
      </div>
    </section>
  );
}
