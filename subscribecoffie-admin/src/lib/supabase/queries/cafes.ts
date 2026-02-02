import { createAdminClient } from "../admin";

export type CafeRecord = {
  id: string;
  name?: string | null;
  address?: string | null;
  mode?: string | null;
  eta_minutes?: number | null;
  supports_citypass?: boolean | null;
  distance_km?: number | null;
  rating?: number | null;
  avg_check_credits?: number | null;
};

export async function listCafes(q?: string): Promise<{
  data: CafeRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  let query = supabase.from("cafes").select("*").order("name");

  if (q) {
    query = query.ilike("name", `%${q}%`);
  }

  const { data, error } = await query;

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data as CafeRecord[]) ?? [] };
}
