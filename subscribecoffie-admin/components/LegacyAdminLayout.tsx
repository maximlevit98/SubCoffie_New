import Link from "next/link";
import { getUserRole } from "@/lib/supabase/roles";

export default async function LegacyAdminLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { role } = await getUserRole();

  return (
    <>
      <header className="border-b border-zinc-200 bg-white px-6 py-4">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold">SubscribeCoffie Admin</h1>
          {/* Removed owner panel links - strict context separation */}
        </div>
      </header>
      <div className="flex min-h-[calc(100vh-64px)]">
        <aside className="w-56 border-r border-zinc-200 bg-white px-4 py-6">
          <nav className="flex flex-col gap-2 text-sm font-medium text-zinc-700">
            <Link
              href="/admin/dashboard"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              📊 Dashboard
            </Link>
            <Link
              href="/admin/orders"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              📦 Заказы
            </Link>
            <Link
              href="/admin/wallets"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              💳 Кошельки
            </Link>
            <Link
              href="/admin/payments"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              💰 Financial Control
            </Link>
            {role === "admin" && (
              <Link
                href="/admin/commission-settings"
                className="rounded px-3 py-2 hover:bg-zinc-100"
              >
                ⚙️ Комиссии
              </Link>
            )}
            <div className="my-2 border-t border-zinc-200"></div>
            <Link
              href="/admin/cafes"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              ☕ Кафе
            </Link>
            <Link
              href="/admin/menu"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              📋 Меню
            </Link>
            {role === "admin" && (
              <Link
                href="/admin/menu-items"
                className="rounded px-3 py-2 hover:bg-zinc-100"
              >
                🍽️ Позиции меню
              </Link>
            )}
            {role === "admin" && (
              <Link
                href="/admin/cafe-onboarding"
                className="rounded px-3 py-2 hover:bg-zinc-100"
              >
                🏪 Заявки на подключение
              </Link>
            )}
            {role === "admin" && (
              <Link
                href="/admin/owner-invitations"
                className="rounded px-3 py-2 hover:bg-zinc-100"
              >
                📨 Owner Invitations
              </Link>
            )}
            {/* Removed "Owner Panel" and "Legacy Owner" links - admins stay in admin context */}
          </nav>
        </aside>
        <main className="flex-1 px-6 py-6">{children}</main>
      </div>
    </>
  );
}
