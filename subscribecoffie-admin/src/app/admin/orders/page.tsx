import { redirect } from "next/navigation";

import { createServerClient } from "../../../lib/supabase/server";
import { listOrders } from "../../../lib/supabase/queries/orders";
import OrdersClient from "./OrdersClient";

export default async function OrdersPage() {
  const supabase = await createServerClient();
  const { data: claimsData, error: claimsError } =
    await supabase.auth.getClaims();

  if (claimsError || !claimsData?.claims) {
    redirect("/login");
  }

  const userId = claimsData.claims.sub;
  const { data: profileData, error: profileError } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .limit(1)
    .maybeSingle();

  async function handleLogout() {
    "use server";
    const supabaseClient = await createServerClient();
    await supabaseClient.auth.signOut();
    redirect("/login");
  }

  if (profileError || profileData?.role !== "admin") {
    return (
      <section className="space-y-6">
        <div className="rounded border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-xl font-semibold text-zinc-900">Нет доступа</h2>
          <p className="mt-2 text-sm text-zinc-600">
            У вас нет прав администратора для доступа к заказам.
          </p>
          <form action={handleLogout} className="mt-4">
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
            >
              Выйти
            </button>
          </form>
        </div>
      </section>
    );
  }

  const { data, error } = await listOrders();

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Orders</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить заказы: {error}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Orders</h2>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>
      <OrdersClient initialOrders={data ?? []} />
    </section>
  );
}
