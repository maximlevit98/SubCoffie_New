import { redirect } from "next/navigation";

import { createServerClient } from "../../../lib/supabase/server";
import { listMenuItems } from "../../../lib/supabase/queries/menu-items";

type MenuPageProps = {
  searchParams?: Promise<{
    cafe_id?: string;
  }>;
};

export default async function MenuPage({ searchParams }: MenuPageProps) {
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
            У вас нет прав администратора для доступа к меню.
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

  const resolvedParams = await searchParams;
  const cafeId = resolvedParams?.cafe_id?.trim() ?? "";
  const { data, error } = await listMenuItems(cafeId || undefined);

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Menu</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить меню: {error}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Menu</h2>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>
      <form action="/admin/menu" method="get" className="flex items-center gap-3">
        <input
          type="text"
          name="cafe_id"
          placeholder="Filter by cafe_id"
          defaultValue={cafeId}
          className="w-full max-w-sm rounded border border-zinc-300 px-3 py-2 text-sm"
        />
        <button
          type="submit"
          className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
        >
          Filter
        </button>
      </form>
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">ID</th>
              <th className="px-4 py-3 font-medium">Cafe ID</th>
              <th className="px-4 py-3 font-medium">Category</th>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Price</th>
              <th className="px-4 py-3 font-medium">Available</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {(data ?? []).map((item) => (
              <tr key={item.id} className="text-zinc-700">
                <td className="px-4 py-3 font-mono text-xs text-zinc-900">
                  {item.id}
                </td>
                <td className="px-4 py-3 font-mono text-xs">
                  {item.cafe_id}
                </td>
                <td className="px-4 py-3">{item.category}</td>
                <td className="px-4 py-3">{item.name}</td>
                <td className="px-4 py-3">{item.price_credits}</td>
                <td className="px-4 py-3">
                  {item.is_available ? "Yes" : "No"}
                </td>
              </tr>
            ))}
            {data && data.length === 0 && (
              <tr>
                <td className="px-4 py-6 text-sm text-zinc-500" colSpan={6}>
                  Menu items not found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
