import { createServerClient } from "@/lib/supabase/server";

export async function listUsers(filters?: {
  search?: string;
  role?: string;
  limit?: number;
  offset?: number;
}) {
  const supabase = await createServerClient();
  
  let query = supabase
    .from("profiles")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false });
  
  // Apply search filter (search by name, email, or phone)
  if (filters?.search) {
    query = query.or(
      `full_name.ilike.%${filters.search}%,email.ilike.%${filters.search}%,phone.ilike.%${filters.search}%`
    );
  }
  
  // Apply role filter
  if (filters?.role) {
    query = query.eq("role", filters.role);
  }
  
  // Apply pagination
  const limit = filters?.limit || 50;
  const offset = filters?.offset || 0;
  query = query.range(offset, offset + limit - 1);
  
  const { data, error, count } = await query;
  
  if (error) {
    throw new Error(`Failed to fetch users: ${error.message}`);
  }
  
  return { users: data || [], total: count || 0 };
}

export async function getUserDetails(userId: string) {
  const supabase = await createServerClient();
  
  // Get user profile
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();
  
  if (profileError) {
    throw new Error(`Failed to fetch user profile: ${profileError.message}`);
  }
  
  // Get user orders count
  const { count: ordersCount } = await supabase
    .from("orders_core")
    .select("*", { count: "exact", head: true })
    .eq("customer_user_id", userId);
  
  // Get user wallets
  const { data: wallets } = await supabase
    .from("wallets")
    .select("*")
    .eq("user_id", userId);
  
  return {
    profile,
    ordersCount: ordersCount || 0,
    wallets: wallets || [],
  };
}

export async function getUsersStats() {
  const supabase = await createServerClient();
  
  // Total users count
  const { count: totalUsers } = await supabase
    .from("profiles")
    .select("*", { count: "exact", head: true });
  
  // Users by role
  const { data: roleStats } = await supabase
    .from("profiles")
    .select("role")
    .then(({ data }) => {
      const stats: Record<string, number> = {};
      data?.forEach((row) => {
        stats[row.role] = (stats[row.role] || 0) + 1;
      });
      return { data: stats };
    });
  
  // Users registered in last 30 days
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const { count: newUsers } = await supabase
    .from("profiles")
    .select("*", { count: "exact", head: true })
    .gte("created_at", thirtyDaysAgo.toISOString());
  
  return {
    totalUsers: totalUsers || 0,
    roleStats: roleStats || {},
    newUsers: newUsers || 0,
  };
}
