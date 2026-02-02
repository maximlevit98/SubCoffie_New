import { createAdminClient } from "../admin";

export type OrderRecord = {
  id: string;
  status: string | null;
  created_at: string | null;
  cafe_id: string | null;
  customer_phone: string | null;
  issued_at: string | null;
};

export async function listOrders(limit = 50): Promise<{
  data: OrderRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("orders")
    .select("id,status,created_at,cafe_id,customer_phone,issued_at")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data as OrderRecord[]) ?? [] };
}
