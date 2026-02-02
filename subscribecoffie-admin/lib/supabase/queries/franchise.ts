import { createAdminClient } from "../admin";

export type FranchisePartnerRecord = {
  franchise_id: string;
  user_id: string;
  user_email: string | null;
  company_name: string;
  contact_person: string;
  email: string;
  phone: string;
  commission_rate: number;
  status: string;
  region_count: number | null;
  cafe_count: number;
  created_at: string;
};

export type FranchisePartnerDetails = {
  franchise_id: string;
  user_id: string;
  user_email: string | null;
  company_name: string;
  contact_person: string;
  email: string;
  phone: string;
  tax_id: string | null;
  regions: string[] | null;
  contract_number: string | null;
  contract_start_date: string | null;
  contract_end_date: string | null;
  commission_rate: number;
  status: string;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export async function getAllFranchisePartners(
  status: string | null = null,
  limit = 50,
  offset = 0
): Promise<{
  data: FranchisePartnerRecord[] | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase.rpc("get_all_franchise_partners", {
    p_status: status,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: (data as FranchisePartnerRecord[]) ?? [] };
}

export async function getFranchisePartnerDetails(
  franchiseId: string
): Promise<{
  data: FranchisePartnerDetails | null;
  error?: string;
}> {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase.rpc("get_franchise_partner_details", {
    p_franchise_id: franchiseId,
  });

  if (error) {
    return { data: null, error: error.message };
  }

  if (!data || data.length === 0) {
    return { data: null, error: "Franchise partner not found" };
  }

  return { data: data[0] as FranchisePartnerDetails };
}
