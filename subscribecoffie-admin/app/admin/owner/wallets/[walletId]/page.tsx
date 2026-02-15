import Link from "next/link";
import { getUserRole } from "@/lib/supabase/roles";
import { redirect } from "next/navigation";
import {
  getOwnerWalletOverview,
  getOwnerWalletTransactions,
  getOwnerWalletPayments,
  getOwnerWalletOrders,
} from "@/lib/supabase/queries/owner-wallets";
import { OwnerWalletDetailClient } from "./OwnerWalletDetailClient";

type OwnerWalletDetailsPageProps = {
  params: Promise<{
    walletId: string;
  }>;
};

export default async function OwnerWalletDetailsPage({
  params,
}: OwnerWalletDetailsPageProps) {
  // Auth check
  const { role, userId } = await getUserRole();

  if (!role || !userId) {
    redirect("/login");
  }

  if (role !== "owner" && role !== "admin") {
    redirect("/admin/owner/dashboard");
  }

  const { walletId } = await params;
  let error: string | null = null;

  // Fetch detailed data for this wallet (owner RPC will check ownership)
  const [
    { data: overview, error: overviewError },
    { data: transactions, error: transactionsError },
    { data: payments, error: paymentsError },
    { data: orders, error: ordersError },
  ] = await Promise.all([
    getOwnerWalletOverview(walletId),
    getOwnerWalletTransactions(walletId, 50, 0),
    getOwnerWalletPayments(walletId, 50, 0),
    getOwnerWalletOrders(walletId, 50, 0),
  ]);

  if (overviewError || transactionsError || paymentsError || ordersError) {
    error =
      overviewError ||
      transactionsError ||
      paymentsError ||
      ordersError ||
      "Unknown error";
  }

  if (error) {
    return (
      <section className="space-y-4 p-6">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошелёк</h2>
          <Link
            href="/admin/owner/wallets"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к кошелькам
          </Link>
        </div>
        <div className="rounded-lg border border-red-200 bg-red-50 p-6">
          <div className="flex items-start gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <h3 className="mb-2 font-semibold text-red-900">
                Ошибка загрузки данных
              </h3>
              <p className="text-sm text-red-700">{error}</p>
              <p className="mt-2 text-xs text-red-600">
                Возможно, этот кошелёк не привязан к вашим кофейням
              </p>
            </div>
          </div>
        </div>
      </section>
    );
  }

  if (!overview) {
    return (
      <section className="space-y-4 p-6">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Кошелёк</h2>
          <Link
            href="/admin/owner/wallets"
            className="text-sm text-zinc-600 hover:text-zinc-900"
          >
            ← Назад к кошелькам
          </Link>
        </div>
        <div className="rounded-lg border border-amber-200 bg-amber-50 p-6">
          <p className="text-sm text-amber-800">
            Не удалось загрузить данные кошелька
          </p>
        </div>
      </section>
    );
  }

  return (
    <section className="p-6">
      <OwnerWalletDetailClient
        overview={overview}
        transactions={transactions || []}
        payments={payments || []}
        orders={orders || []}
      />
    </section>
  );
}
