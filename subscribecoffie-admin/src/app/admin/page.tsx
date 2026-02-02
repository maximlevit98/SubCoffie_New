import { redirect } from "next/navigation";

import { createServerClient } from "../../lib/supabase/server";

export default async function AdminPage() {
  const supabase = await createServerClient();
  const { data: claimsData, error: claimsError } =
    await supabase.auth.getClaims();

  if (claimsError || !claimsData?.claims) {
    redirect("/login");
  }

  const userId = claimsData.claims.sub;
  const { data: userData } = await supabase.auth.getUser();
  const email =
    userData.user?.email ?? claimsData.claims.email ?? "unknown@email";

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
            У вас нет прав администратора для доступа к панели.
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

  return (
    <section className="space-y-6">
      <div className="rounded border border-zinc-200 bg-white p-6 shadow-sm">
        <h2 className="text-xl font-semibold text-zinc-900">
          Admin Dashboard (MVP)
        </h2>
        <p className="mt-2 text-sm text-zinc-600">Email: {email}</p>
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
