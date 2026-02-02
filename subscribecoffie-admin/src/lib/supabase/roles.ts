import { createServerClient } from "./server";

export type UserRole = "admin" | "owner" | "user";

export async function getUserRole() {
  const supabase = await createServerClient();
  const { data: claimsData, error: claimsError } =
    await supabase.auth.getClaims();

  if (claimsError || !claimsData?.claims) {
    return { role: null, userId: null };
  }

  const userId = claimsData.claims.sub;
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
