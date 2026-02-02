import Link from "next/link";
import { redirect } from "next/navigation";

import { getUserRole } from "../../lib/supabase/roles";

export default async function AdminLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { role } = await getUserRole();

  if (!role) {
    redirect("/login");
  }

  return (
    <div className="min-h-screen bg-zinc-50 font-sans text-zinc-900">
      <header className="border-b border-zinc-200 bg-white px-6 py-4">
        <h1 className="text-lg font-semibold">SubscribeCoffie Admin</h1>
      </header>
      <div className="flex min-h-[calc(100vh-64px)]">
        <aside className="w-56 border-r border-zinc-200 bg-white px-4 py-6">
          <nav className="flex flex-col gap-2 text-sm font-medium text-zinc-700">
            <Link
              href="/admin/cafes"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              Cafes
            </Link>
            <Link
              href="/admin/orders"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              Orders
            </Link>
            <Link
              href="/admin/menu"
              className="rounded px-3 py-2 hover:bg-zinc-100"
            >
              Menu
            </Link>
            {role === "admin" && (
              <Link
                href="/admin/menu-items"
                className="rounded px-3 py-2 hover:bg-zinc-100"
              >
                Menu Items
              </Link>
            )}
          </nav>
        </aside>
        <main className="flex-1 px-6 py-6">{children}</main>
      </div>
    </div>
  );
}
