import { createServerClient } from "./server";

export type UserRole = "admin" | "owner" | "user";

export async function getUserRole() {
  const supabase = await createServerClient();

  // Get authenticated user
  const { data: { user }, error: userError } = await supabase.auth.getUser();

  if (userError || !user) {
    return { role: null, userId: null };
  }

  const userId = user.id;

  // Try to get role from user_roles table first (preferred)
  const { data: userRoleData } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", userId)
    .limit(1)
    .maybeSingle();

  if (userRoleData?.role) {
    return { role: userRoleData.role as UserRole, userId };
  }

  // Fallback to profiles table for backward compatibility
  const { data: profileData } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .limit(1)
    .maybeSingle();

  const role = (profileData?.role as UserRole | undefined) ?? null;
  return { role, userId };
}

export async function requireAdmin() {
  const { role, userId } = await getUserRole();
  if (role !== "admin" || !userId) {
    throw new Error("Admin role required");
  }
  return { userId };
}
