import { createAdminClient } from "../admin";

export type RegionRecord = {
  region_id: string;
  region_name: string;
  city: string;
  country: string;
  timezone: string;
  is_active: boolean;
  latitude: number | null;
  longitude: number | null;
  cafe_count: number;
  created_at: string;
};

export type RegionCafeRecord = {
  cafe_id: string;
  cafe_name: string;
  cafe_address: string;
  cafe_mode: string;
  cafe_latitude: number | null;
  cafe_longitude: number | null;
  assigned_at: string;
};

export async function getAllRegions(includeInactive = false): Promise<{
  data: RegionRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase.rpc("get_all_regions", {
    p_include_inactive: includeInactive,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data as RegionRecord[]) ?? [] };
}

export async function getCafesInRegion(
  regionId: string,
  limit = 50,
  offset = 0
): Promise<{
  data: RegionCafeRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase.rpc("get_cafes_in_region", {
    p_region_id: regionId,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data as RegionCafeRecord[]) ?? [] };
}

export async function getRegionById(
  regionId: string
): Promise<{
  data: RegionRecord | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  
  const { data: regions, error } = await supabase.rpc("get_all_regions", {
    p_include_inactive: true,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  const region = (regions as RegionRecord[])?.find(
    (r) => r.region_id === regionId
  );

  if (!region) {
    return { data: null, error: "Region not found" };
  }

  return { data: region };
}
