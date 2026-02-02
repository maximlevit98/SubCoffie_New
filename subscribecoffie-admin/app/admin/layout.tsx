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
      {/* Render children directly without the admin layout wrapper */}
      {children}
    </div>
  );
}
