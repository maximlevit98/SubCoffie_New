import { createAdminClient } from "../admin";

export type OrderItemRecord = {
  id: string;
  item_name: string;
  quantity: number;
  total_price_credits: number;
  base_price_credits?: number;
  modifiers?: any;
};

export type OrderRecord = {
  id: string;
  cafe_id: string;
  order_number: string | null;
  order_type: string;
  status: string;
  payment_status: string;
  payment_method: string | null;
  
  customer_name: string | null;
  customer_phone: string | null;
  customer_notes: string | null;
  
  subtotal_credits: number;
  total_credits: number;
  
  created_at: string;
  order_items?: OrderItemRecord[];
};

export async function listOrders(limit = 50): Promise<{
  data: OrderRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("orders_core")
    .select(`
      id,
      cafe_id,
      order_number,
      order_type,
      status,
      payment_status,
      payment_method,
      customer_name,
      customer_phone,
      customer_notes,
      subtotal_credits,
      total_credits,
      created_at,
      order_items (
        id,
        item_name,
        quantity,
        total_price_credits,
        base_price_credits,
        modifiers
      )
    `)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data as OrderRecord[]) ?? [] };
}

export async function listOrdersByCafe(
  cafeId: string,
  status?: string
): Promise<{ data: OrderRecord[] | null; error?: string }> {
  const supabase = createAdminClient();
  
  let query = supabase
    .from("orders_core")
    .select(`
      id,
      cafe_id,
      order_number,
      order_type,
      status,
      payment_status,
      payment_method,
      customer_name,
      customer_phone,
      customer_notes,
      subtotal_credits,
      total_credits,
      created_at,
      order_items (
        id,
        item_name,
        quantity,
        total_price_credits,
        base_price_credits,
        modifiers
      )
    `)
    .eq("cafe_id", cafeId)
    .order("created_at", { ascending: false });

  if (status) {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data as OrderRecord[] };
}

export async function getOrderStats(cafeId: string): Promise<{
  data: {
    ordersToday: number;
    revenueToday: number;
    activeOrders: number;
  } | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const { data, error } = await supabase
    .from("orders_core")
    .select("status, total_credits, created_at")
    .eq("cafe_id", cafeId)
    .gte("created_at", today.toISOString());

  if (error) {
    return { data: null, error: error.message };
  }

  const ordersToday = data?.length ?? 0;
  const revenueToday = data?.reduce((sum, o) => sum + (o.total_credits ?? 0), 0) ?? 0;
  const activeOrders = data?.filter(o => 
    ['created', 'accepted', 'in_progress', 'preparing', 'ready'].includes(o.status)
  ).length ?? 0;

  return {
    data: { ordersToday, revenueToday, activeOrders }
  };
}
