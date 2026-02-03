import { createServerClient } from "./server";
import { NextResponse } from "next/server";

export type UserRole = "admin" | "owner" | "user";

/**
 * Get current user's role and ID
 */
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

/**
 * Require admin role
 * @throws Error if user is not admin
 */
export async function requireAdmin() {
  const { role, userId } = await getUserRole();
  if (role !== "admin" || !userId) {
    throw new Error("Admin role required");
  }
  return { userId };
}

/**
 * Require owner or admin role
 * @returns NextResponse error or { userId, role, supabase }
 */
export async function requireOwnerOrAdmin() {
  const { role, userId } = await getUserRole();

  if (!userId) {
    return NextResponse.json(
      { error: "Authentication required" },
      { status: 401 }
    );
  }

  if (role !== "owner" && role !== "admin") {
    return NextResponse.json(
      { error: "Owner or admin role required" },
      { status: 403 }
    );
  }

  const supabase = await createServerClient();
  return { userId, role, supabase };
}

/**
 * Verify cafe ownership for owner users
 * Admins bypass this check
 * @param supabase Supabase client
 * @param userId Current user ID
 * @param role Current user role
 * @param cafeId Cafe ID to verify
 * @returns NextResponse error or null (if ownership verified)
 */
export async function verifyCafeOwnership(
  supabase: any,
  userId: string,
  role: UserRole,
  cafeId: string
): Promise<NextResponse | null> {
  // Admins bypass ownership checks
  if (role === "admin") {
    return null;
  }

  // For owners, verify they own this cafe
  const { data: cafe } = await supabase
    .from("cafes")
    .select("account_id")
    .eq("id", cafeId)
    .single();

  if (!cafe) {
    return NextResponse.json(
      { error: "Cafe not found" },
      { status: 404 }
    );
  }

  const { data: account } = await supabase
    .from("accounts")
    .select("id")
    .eq("id", cafe.account_id)
    .eq("owner_user_id", userId)
    .single();

  if (!account) {
    return NextResponse.json(
      { error: "You do not have access to this cafe" },
      { status: 403 }
    );
  }

  return null; // Ownership verified
}

/**
 * Verify menu item ownership via cafe
 * Admins bypass this check
 * @param supabase Supabase client
 * @param userId Current user ID
 * @param role Current user role
 * @param menuItemId Menu item ID to verify
 * @returns NextResponse error or { cafeId } (if ownership verified)
 */
export async function verifyMenuItemOwnership(
  supabase: any,
  userId: string,
  role: UserRole,
  menuItemId: string
): Promise<NextResponse | { cafeId: string }> {
  // Get menu item
  const { data: menuItem } = await supabase
    .from("menu_items")
    .select("cafe_id, cafes(account_id)")
    .eq("id", menuItemId)
    .single();

  if (!menuItem) {
    return NextResponse.json(
      { error: "Menu item not found" },
      { status: 404 }
    );
  }

  const cafeId = menuItem.cafe_id;

  // Admins bypass ownership checks
  if (role === "admin") {
    return { cafeId };
  }

  // For owners, verify they own the cafe
  const { data: account } = await supabase
    .from("accounts")
    .select("id")
    .eq("id", (menuItem.cafes as any).account_id)
    .eq("owner_user_id", userId)
    .single();

  if (!account) {
    return NextResponse.json(
      { error: "You do not have access to this menu item" },
      { status: 403 }
    );
  }

  return { cafeId };
}

/**
 * Safe error response (no internal details leaked)
 * @param error Error object
 * @param defaultMessage Default user-facing message
 * @param status HTTP status code
 */
export function safeErrorResponse(
  error: any,
  defaultMessage: string = "An error occurred",
  status: number = 500
): NextResponse {
  // Log full error server-side for debugging
  console.error("API Error:", error);

  // Return sanitized error to client (no SQL/internal details)
  return NextResponse.json(
    { error: defaultMessage },
    { status }
  );
}
