import { redirect } from "next/navigation";
import { getUserRole } from "../../lib/supabase/roles";

export default async function AdminHome() {
  const { role } = await getUserRole();

  // Redirect based on role
  if (role === 'owner') {
    redirect("/admin/owner/dashboard");
  }
  
  redirect("/admin/dashboard");
}
