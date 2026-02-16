import { redirect } from "next/navigation";

import LegacyAdminLayout from "@/components/LegacyAdminLayout";
import { getUserRole } from "@/lib/supabase/roles";

export default async function AdminWalletsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { role, userId } = await getUserRole();

  if (!userId) {
    redirect("/login");
  }

  if (role === "owner") {
    redirect("/admin/owner/wallets");
  }

  if (role !== "admin") {
    redirect("/admin/dashboard");
  }

  return <LegacyAdminLayout>{children}</LegacyAdminLayout>;
}
