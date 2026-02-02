import { createAdminClient } from "../admin";

// ==============================================
// PROMO CODES
// ==============================================

export async function listPromoCodes(includeInactive = false) {
  const supabase = createAdminClient();
  let query = supabase
    .from("promo_codes")
    .select("*")
    .order("created_at", { ascending: false });

  if (!includeInactive) {
    query = query.eq("active", true);
  }

  const { data, error } = await query;

  if (error) {
    console.error("Error listing promo codes:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getPromoCodeById(id: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("promo_codes")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (error) {
    console.error(`Error fetching promo code ${id}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getPromoCodeByCode(code: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("promo_codes")
    .select("*")
    .eq("code", code.toUpperCase())
    .maybeSingle();

  if (error) {
    console.error(`Error fetching promo code ${code}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function createPromoCode(promoData: {
  code: string;
  description?: string;
  discount_type: "percentage" | "fixed_amount" | "free_item";
  discount_value: number;
  min_order_amount?: number;
  max_discount_amount?: number;
  max_uses?: number;
  max_uses_per_user?: number;
  valid_from?: string;
  valid_until?: string;
  applicable_cafe_ids?: string[];
  applicable_menu_item_ids?: string[];
  created_by?: string;
}) {
  const supabase = createAdminClient();
  
  // Ensure code is uppercase
  const dataToInsert = {
    ...promoData,
    code: promoData.code.toUpperCase(),
  };

  const { data, error } = await supabase
    .from("promo_codes")
    .insert(dataToInsert)
    .select()
    .single();

  if (error) {
    console.error("Error creating promo code:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function updatePromoCode(
  id: string,
  updates: Partial<{
    description: string;
    discount_type: "percentage" | "fixed_amount" | "free_item";
    discount_value: number;
    min_order_amount: number;
    max_discount_amount: number;
    max_uses: number;
    max_uses_per_user: number;
    valid_from: string;
    valid_until: string;
    active: boolean;
    applicable_cafe_ids: string[];
    applicable_menu_item_ids: string[];
  }>
) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("promo_codes")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select()
    .single();

  if (error) {
    console.error(`Error updating promo code ${id}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function deletePromoCode(id: string) {
  const supabase = createAdminClient();
  const { error } = await supabase
    .from("promo_codes")
    .delete()
    .eq("id", id);

  if (error) {
    console.error(`Error deleting promo code ${id}:`, error);
    return { error: error.message };
  }
  return { error: null };
}

export async function togglePromoCodeStatus(id: string, active: boolean) {
  const supabase = createAdminClient();
  const { error } = await supabase
    .from("promo_codes")
    .update({ active, updated_at: new Date().toISOString() })
    .eq("id", id);

  if (error) {
    console.error(`Error toggling promo code status ${id}:`, error);
    return { error: error.message };
  }
  return { error: null };
}

// ==============================================
// PROMO USAGE
// ==============================================

export async function getPromoUsage(promoCodeId: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("promo_usage")
    .select(`
      *,
      users:user_id (
        email
      ),
      orders:order_id (
        id,
        status
      )
    `)
    .eq("promo_code_id", promoCodeId)
    .order("used_at", { ascending: false });

  if (error) {
    console.error(`Error fetching usage for promo ${promoCodeId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getUserPromoUsage(userId: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("promo_usage")
    .select(`
      *,
      promo_codes:promo_code_id (
        code,
        description,
        discount_type,
        discount_value
      )
    `)
    .eq("user_id", userId)
    .order("used_at", { ascending: false });

  if (error) {
    console.error(`Error fetching promo usage for user ${userId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

// ==============================================
// CAMPAIGNS
// ==============================================

export async function listCampaigns(status?: string) {
  const supabase = createAdminClient();
  let query = supabase
    .from("campaigns")
    .select(`
      *,
      promo_codes:promo_code_id (
        code,
        description
      )
    `)
    .order("created_at", { ascending: false });

  if (status) {
    query = query.eq("status", status);
  }

  const { data, error } = await query;

  if (error) {
    console.error("Error listing campaigns:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getCampaignById(id: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("campaigns")
    .select(`
      *,
      promo_codes:promo_code_id (
        code,
        description,
        discount_type,
        discount_value,
        uses_count
      )
    `)
    .eq("id", id)
    .maybeSingle();

  if (error) {
    console.error(`Error fetching campaign ${id}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function createCampaign(campaignData: {
  name: string;
  description?: string;
  campaign_type: "promo" | "push_notification" | "email" | "banner" | "loyalty";
  status?: "draft" | "scheduled" | "active" | "paused" | "completed" | "cancelled";
  start_date?: string;
  end_date?: string;
  target_segment?: Record<string, any>;
  promo_code_id?: string;
  created_by?: string;
}) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("campaigns")
    .insert(campaignData)
    .select()
    .single();

  if (error) {
    console.error("Error creating campaign:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function updateCampaign(
  id: string,
  updates: Partial<{
    name: string;
    description: string;
    status: "draft" | "scheduled" | "active" | "paused" | "completed" | "cancelled";
    start_date: string;
    end_date: string;
    target_segment: Record<string, any>;
    impressions_count: number;
    clicks_count: number;
    conversions_count: number;
  }>
) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("campaigns")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select()
    .single();

  if (error) {
    console.error(`Error updating campaign ${id}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function deleteCampaign(id: string) {
  const supabase = createAdminClient();
  const { error } = await supabase
    .from("campaigns")
    .delete()
    .eq("id", id);

  if (error) {
    console.error(`Error deleting campaign ${id}:`, error);
    return { error: error.message };
  }
  return { error: null };
}

// ==============================================
// PUSH CAMPAIGNS
// ==============================================

export async function listPushCampaigns() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("push_campaigns")
    .select(`
      *,
      campaigns:campaign_id (
        name,
        status
      )
    `)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("Error listing push campaigns:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function createPushCampaign(pushData: {
  campaign_id?: string;
  title: string;
  message: string;
  target_segment: "all" | "new_users" | "active_users" | "dormant_users" | "vip_users" | "custom";
  custom_segment_filter?: Record<string, any>;
  action_type?: "open_app" | "open_cafe" | "open_promo" | "open_order";
  action_data?: Record<string, any>;
  scheduled_at?: string;
  created_by?: string;
}) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("push_campaigns")
    .insert(pushData)
    .select()
    .single();

  if (error) {
    console.error("Error creating push campaign:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function sendPushCampaign(campaignId: string, userSegment: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase.rpc("send_push_campaign", {
    p_campaign_id: campaignId,
    p_user_segment: userSegment,
  });

  if (error) {
    console.error(`Error sending push campaign ${campaignId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

// ==============================================
// ANALYTICS
// ==============================================

export async function getCampaignAnalytics(
  campaignId?: string,
  startDate?: string,
  endDate?: string
) {
  const supabase = createAdminClient();
  const { data, error } = await supabase.rpc("get_campaign_analytics", {
    p_campaign_id: campaignId || null,
    p_start_date: startDate || null,
    p_end_date: endDate || null,
  });

  if (error) {
    console.error("Error fetching campaign analytics:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getPromoCodesSummary() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("active_promo_codes_summary")
    .select("*");

  if (error) {
    console.error("Error fetching promo codes summary:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getCampaignPerformance() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("campaign_performance")
    .select("*")
    .limit(50);

  if (error) {
    console.error("Error fetching campaign performance:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

// ==============================================
// VALIDATION
// ==============================================

export async function validatePromoCode(
  code: string,
  userId: string,
  orderAmount: number
) {
  const supabase = createAdminClient();
  const { data, error } = await supabase.rpc("validate_promo_code", {
    p_code: code,
    p_user_id: userId,
    p_order_amount: orderAmount,
  });

  if (error) {
    console.error(`Error validating promo code ${code}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}
