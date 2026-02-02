import { createAdminClient } from "../admin";

export async function listPaymentTransactions(limit = 100) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("payment_transactions")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("Error listing payment transactions:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getTransactionById(id: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("payment_transactions")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (error) {
    console.error(`Error fetching transaction ${id}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getCommissionConfig() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("commission_config")
    .select("*")
    .order("operation_type");

  if (error) {
    console.error("Error fetching commission config:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function updateCommissionRate(
  operationType: string,
  commissionPercent: number
) {
  const supabase = createAdminClient();
  const { error } = await supabase
    .from("commission_config")
    .update({ commission_percent: commissionPercent, updated_at: new Date().toISOString() })
    .eq("operation_type", operationType);

  if (error) {
    console.error(`Error updating commission rate for ${operationType}:`, error);
    return { error: error.message };
  }
  return { error: null };
}

export async function listWalletNetworks() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("wallet_networks")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("Error listing wallet networks:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getNetworkById(id: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("wallet_networks")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (error) {
    console.error(`Error fetching network ${id}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getNetworkCafes(networkId: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("cafe_network_members")
    .select("cafe_id, cafes(id, name, address)")
    .eq("network_id", networkId);

  if (error) {
    console.error(`Error fetching cafes for network ${networkId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}
