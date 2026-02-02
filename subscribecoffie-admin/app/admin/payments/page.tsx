import Link from "next/link";
import { listPaymentTransactions } from "../../../lib/supabase/queries/payments";

export default async function PaymentsPage() {
  const { data: transactions, error } = await listPaymentTransactions();

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Payments</h2>
          <span className="rounded-full bg-red-100 px-3 py-1 text-xs font-medium text-red-700">
            DEMO MODE
          </span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить транзакции: {error}
        </p>
      </section>
    );
  }

  const totalRevenue = transactions?.reduce((sum, tx) => {
    if (tx.status === "completed") {
      return sum + (tx.commission_credits || 0);
    }
    return sum;
  }, 0) || 0;

  const totalAmount = transactions?.reduce((sum, tx) => {
    if (tx.status === "completed") {
      return sum + (tx.amount_credits || 0);
    }
    return sum;
  }, 0) || 0;

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Payments</h2>
        <span className="rounded-full bg-yellow-100 px-3 py-1 text-xs font-medium text-yellow-700">
          DEMO MODE
        </span>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Transactions</div>
          <div className="text-2xl font-bold text-zinc-900">
            {transactions?.length || 0}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Processed (Mock)</div>
          <div className="text-2xl font-bold text-zinc-900">
            {totalAmount.toLocaleString()} ₽
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Platform Revenue (Mock)</div>
          <div className="text-2xl font-bold text-emerald-600">
            {totalRevenue.toLocaleString()} ₽
          </div>
        </div>
      </div>

      {/* Transactions Table */}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Commission</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Provider ID</th>
              <th className="px-4 py-3 font-medium">Created</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {transactions && transactions.length > 0 ? (
              transactions.map((tx) => (
                <tr key={tx.id} className="text-zinc-700">
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block rounded px-2 py-1 text-xs font-medium ${
                        tx.transaction_type === "topup"
                          ? "bg-blue-100 text-blue-700"
                          : tx.transaction_type === "order_payment"
                          ? "bg-green-100 text-green-700"
                          : "bg-orange-100 text-orange-700"
                      }`}
                    >
                      {tx.transaction_type}
                    </span>
                  </td>
                  <td className="px-4 py-3 font-mono">
                    {tx.amount_credits?.toLocaleString() || 0} ₽
                  </td>
                  <td className="px-4 py-3 font-mono text-emerald-600">
                    {tx.commission_credits?.toLocaleString() || 0} ₽
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-block rounded px-2 py-1 text-xs font-medium ${
                        tx.status === "completed"
                          ? "bg-emerald-100 text-emerald-700"
                          : tx.status === "failed"
                          ? "bg-red-100 text-red-700"
                          : "bg-yellow-100 text-yellow-700"
                      }`}
                    >
                      {tx.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-zinc-500">
                    {tx.provider_transaction_id
                      ? tx.provider_transaction_id.substring(0, 20) + "..."
                      : "—"}
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-600">
                    {tx.created_at
                      ? new Date(tx.created_at).toLocaleString()
                      : "—"}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td className="px-4 py-6 text-sm text-zinc-500" colSpan={6}>
                  No transactions yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="rounded border border-yellow-200 bg-yellow-50 p-4">
        <p className="text-sm text-yellow-800">
          <strong>Demo Mode:</strong> All payments are simulated for MVP testing.
          Real payment integration (Stripe/ЮKassa) will be added after cloud
          deployment.
        </p>
      </div>
    </section>
  );
}
