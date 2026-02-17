import Link from "next/link";
import { redirect } from "next/navigation";

import LegacyAdminLayout from "@/components/LegacyAdminLayout";
import { getUserRole } from "../../lib/supabase/roles";

export default async function AdminLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { role, userId } = await getUserRole();

  // 🔐 GUARD 1: Require authentication
  if (!userId || !role) {
    redirect("/login");
  }

  // 🔐 GUARD 2: Require admin or owner role
  if (role !== 'admin' && role !== 'owner') {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50">
        <div className="w-full max-w-md space-y-4 rounded border border-red-200 bg-red-50 p-6 shadow-sm">
          <div className="space-y-1">
            <h1 className="text-xl font-semibold text-red-900">
              Access Denied
            </h1>
            <p className="text-sm text-red-700">
              You do not have permission to access the admin panel.
            </p>
          </div>
          
          <div className="rounded border border-red-300 bg-white p-4">
            <p className="text-sm text-zinc-700">
              <strong>Your role:</strong> {role}
            </p>
            <p className="text-xs text-zinc-500 mt-2">
              Required: <code className="rounded bg-zinc-100 px-1 py-0.5">admin</code> or{" "}
              <code className="rounded bg-zinc-100 px-1 py-0.5">owner</code>
            </p>
          </div>

          <div className="flex gap-2">
            <Link
              href="/login"
              className="flex-1 rounded border border-zinc-300 px-4 py-2 text-center text-sm font-medium text-zinc-700 hover:bg-zinc-50"
            >
              Back to Login
            </Link>
            <Link
              href="/"
              className="flex-1 rounded bg-zinc-900 px-4 py-2 text-center text-sm font-medium text-white hover:bg-zinc-800"
            >
              Go Home
            </Link>
          </div>
        </div>
      </div>
    );
  }

  if (role === "admin") {
    return <LegacyAdminLayout>{children}</LegacyAdminLayout>;
  }

  return <div className="min-h-screen bg-zinc-50 font-sans text-zinc-900">{children}</div>;
}
