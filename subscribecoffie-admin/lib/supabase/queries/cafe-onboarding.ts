import { createAdminClient } from "../admin";

export type CafeOnboardingRequest = {
  id: string;
  applicant_name: string;
  applicant_email: string;
  applicant_phone: string | null;
  cafe_name: string;
  cafe_address: string;
  cafe_description: string | null;
  status: "pending" | "approved" | "rejected";
  admin_notes: string | null;
  created_at: string;
  updated_at: string;
};

export async function listOnboardingRequests(status?: string) {
  const supabase = createAdminClient();
  
  let query = supabase
    .from("cafe_onboarding_requests")
    .select("*")
    .order("created_at", { ascending: false });
  
  if (status) {
    query = query.eq("status", status);
  }
  
  const { data, error } = await query;
  
  if (error) {
    console.error("Error listing onboarding requests:", error);
    return { data: null, error: error.message };
  }
  
  return { data, error: null };
}

export async function getOnboardingRequest(id: string) {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase
    .from("cafe_onboarding_requests")
    .select("*")
    .eq("id", id)
    .single();
  
  if (error) {
    console.error("Error getting onboarding request:", error);
    return { data: null, error: error.message };
  }
  
  return { data, error: null };
}

export async function updateOnboardingRequestStatus(
  id: string,
  status: string,
  adminNotes?: string
) {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase
    .from("cafe_onboarding_requests")
    .update({
      status,
      admin_notes: adminNotes,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);
  
  if (error) {
    console.error("Error updating onboarding request:", error);
    throw new Error(error.message);
  }
  
  return { data, error: null };
}

export async function approveCafe(requestId: string, adminUserId: string) {
  const supabase = createAdminClient();
  
  const { data, error } = await supabase.rpc("approve_cafe", {
    p_request_id: requestId,
    p_admin_user_id: adminUserId,
  });
  
  if (error) {
    console.error("Error approving cafe:", error);
    throw new Error(error.message);
  }
  
  return { data, error: null };
}
