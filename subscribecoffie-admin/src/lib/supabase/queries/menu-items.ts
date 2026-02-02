import { createAdminClient } from "../admin";

export type MenuItemRecord = {
  id: string;
  cafe_id: string;
  category: string;
  name: string;
  price_credits: number;
  is_available: boolean;
};

export async function listMenuItems(cafeId?: string): Promise<{
  data: MenuItemRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  let query = supabase
    .from("menu_items")
    .select("id,cafe_id,category,name,price_credits,is_available")
    .order("cafe_id")
    .order("category");

  if (cafeId) {
    query = query.eq("cafe_id", cafeId);
  }

  const { data, error } = await query;

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data as MenuItemRecord[]) ?? [] };
}
