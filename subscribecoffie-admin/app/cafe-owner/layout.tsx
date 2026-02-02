import Link from "next/link";
import { redirect } from "next/navigation";

import { getUserRole } from "../../lib/supabase/roles";
import { createServerClient } from "../../lib/supabase/server";

export default async function CafeOwnerLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { role, userId } = await getUserRole();

  if (!role || !userId) {
    redirect("/login");
  }

  if (role !== "owner" && role !== "admin") {
    redirect("/login");
  }

  // Get cafe owner's cafes
  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc("get_owner_cafes");

  return (
    <div className="min-h-screen bg-zinc-50 font-sans text-zinc-900">
      <header className="border-b border-zinc-200 bg-white px-6 py-4">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-lg font-semibold">☕ SubscribeCoffie</h1>
            <p className="text-sm text-zinc-500">Панель владельца кафе</p>
          </div>
          <div className="flex items-center gap-4">
            {role === "admin" && (
              <Link
                href="/admin/dashboard"
                className="text-sm text-blue-600 hover:text-blue-700"
              >
                ← Admin Panel
              </Link>
            )}
            <div className="rounded-lg bg-green-100 px-3 py-1 text-sm font-medium text-green-800">
              Владелец
            </div>
          </div>
        </div>
      </header>
      <div className="flex min-h-[calc(100vh-73px)]">
        <aside className="w-64 border-r border-zinc-200 bg-white px-4 py-6">
          <nav className="flex flex-col gap-2 text-sm font-medium text-zinc-700">
            <Link
              href="/cafe-owner/dashboard"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              📊 Dashboard
            </Link>
            <Link
              href="/cafe-owner/orders"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              📦 Заказы
            </Link>
            <div className="my-2 border-t border-zinc-200"></div>
            <Link
              href="/cafe-owner/menu"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              📋 Меню
            </Link>
            <Link
              href="/cafe-owner/stop-list"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              🚫 Стоп-лист
            </Link>
            <div className="my-2 border-t border-zinc-200"></div>
            <Link
              href="/cafe-owner/analytics"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              📈 Аналитика
            </Link>
            <Link
              href="/cafe-owner/customers"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              👥 Клиенты
            </Link>
            <div className="my-2 border-t border-zinc-200"></div>
            <Link
              href="/cafe-owner/settings"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              ⚙️ Настройки
            </Link>
          </nav>

          {cafes && cafes.length > 0 && (
            <div className="mt-6 rounded-lg border border-zinc-200 bg-zinc-50 p-4">
              <p className="mb-2 text-xs font-semibold uppercase text-zinc-500">
                Мои кафе
              </p>
              <div className="space-y-2">
                {cafes.map((cafe: any) => (
                  <div
                    key={cafe.id}
                    className="rounded-lg bg-white p-2 text-sm"
                  >
                    <p className="font-medium">{cafe.name}</p>
                    <p className="text-xs text-zinc-500">{cafe.address}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </aside>
        <main className="flex-1 px-6 py-6">{children}</main>
      </div>
    </div>
  );
}
