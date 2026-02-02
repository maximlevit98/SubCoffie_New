"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createAdminClient } from "../../../lib/supabase/admin";
import { requireAdmin } from "../../../lib/supabase/roles";

// ==============================================
// HELPER FUNCTIONS
// ==============================================

const parseNumber = (value: FormDataEntryValue | null) => {
  if (value === null || value === "") {
    return null;
  }
  const num = Number(value);
  return Number.isNaN(num) ? null : num;
};

const getRequiredString = (value: FormDataEntryValue | null, field: string) => {
  const trimmed = typeof value === "string" ? value.trim() : "";
  if (!trimmed) {
    throw new Error(`${field} is required`);
  }
  return trimmed;
};

const logAudit = async (
  actorUserId: string,
  action: "create" | "update" | "delete",
  tableName: string,
  recordId: string,
  payload: Record<string, unknown>,
) => {
  const supabase = createAdminClient();
  const { error } = await supabase.from("audit_logs").insert({
    actor_user_id: actorUserId,
    action,
    table_name: tableName,
    record_id: recordId,
    payload,
  });

  if (error) {
    console.error("Failed to log audit:", error);
    // Don't throw - audit logging failure shouldn't break the main action
  }
};

// ==============================================
// PROMO CODE ACTIONS
// ==============================================

export async function createPromoCode(formData: FormData) {
  const { userId } = await requireAdmin();
  
  const code = getRequiredString(formData.get("code"), "Code").toUpperCase();
  const description = (formData.get("description") as string | null)?.trim() || null;
  const discountType = getRequiredString(formData.get("discount_type"), "Discount type");
  const discountValue = parseNumber(formData.get("discount_value"));
  
  if (discountValue === null || discountValue < 0) {
    throw new Error("Discount value must be 0 or higher");
  }

  const minOrderAmount = parseNumber(formData.get("min_order_amount")) || 0;
  const maxDiscountAmount = parseNumber(formData.get("max_discount_amount"));
  const maxUses = parseNumber(formData.get("max_uses"));
  const maxUsesPerUser = parseNumber(formData.get("max_uses_per_user")) || 1;
  
  const validFrom = formData.get("valid_from") as string | null;
  const validUntil = formData.get("valid_until") as string | null;

  const payload = {
    code,
    description,
    discount_type: discountType,
    discount_value: discountValue,
    min_order_amount: minOrderAmount,
    max_discount_amount: maxDiscountAmount,
    max_uses: maxUses,
    max_uses_per_user: maxUsesPerUser,
    valid_from: validFrom ? new Date(validFrom).toISOString() : new Date().toISOString(),
    valid_until: validUntil ? new Date(validUntil).toISOString() : null,
    created_by: userId,
  };

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("promo_codes")
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  if (data?.id) {
    await logAudit(userId, "create", "promo_codes", data.id, payload);
  }

  revalidatePath("/admin/marketing/promo-codes");
  redirect("/admin/marketing/promo-codes");
}

export async function updatePromoCode(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Promo code id");
  
  const description = (formData.get("description") as string | null)?.trim() || null;
  const discountType = getRequiredString(formData.get("discount_type"), "Discount type");
  const discountValue = parseNumber(formData.get("discount_value"));
  
  if (discountValue === null || discountValue < 0) {
    throw new Error("Discount value must be 0 or higher");
  }

  const minOrderAmount = parseNumber(formData.get("min_order_amount")) || 0;
  const maxDiscountAmount = parseNumber(formData.get("max_discount_amount"));
  const maxUses = parseNumber(formData.get("max_uses"));
  const maxUsesPerUser = parseNumber(formData.get("max_uses_per_user")) || 1;
  
  const validFrom = formData.get("valid_from") as string | null;
  const validUntil = formData.get("valid_until") as string | null;
  const active = formData.get("active") === "on" || formData.get("active") === "true";

  const payload = {
    description,
    discount_type: discountType,
    discount_value: discountValue,
    min_order_amount: minOrderAmount,
    max_discount_amount: maxDiscountAmount,
    max_uses: maxUses,
    max_uses_per_user: maxUsesPerUser,
    valid_from: validFrom ? new Date(validFrom).toISOString() : new Date().toISOString(),
    valid_until: validUntil ? new Date(validUntil).toISOString() : null,
    active,
    updated_at: new Date().toISOString(),
  };

  const supabase = createAdminClient();
  const { error } = await supabase
    .from("promo_codes")
    .update(payload)
    .eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "update", "promo_codes", id, payload);

  revalidatePath("/admin/marketing/promo-codes");
  revalidatePath(`/admin/marketing/promo-codes/${id}`);
  redirect("/admin/marketing/promo-codes");
}

export async function togglePromoCodeStatus(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Promo code id");
  const active = formData.get("active") === "on" || formData.get("active") === "true";

  const supabase = createAdminClient();
  const { error } = await supabase
    .from("promo_codes")
    .update({ active, updated_at: new Date().toISOString() })
    .eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "update", "promo_codes", id, { active });

  revalidatePath("/admin/marketing/promo-codes");
  revalidatePath(`/admin/marketing/promo-codes/${id}`);
}

export async function deletePromoCode(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Promo code id");
  const confirmValue = formData.get("confirm");
  const confirmed = confirmValue === "on" || confirmValue === "yes";

  if (!confirmed) {
    throw new Error("Delete confirmation required");
  }

  const supabase = createAdminClient();
  const { error } = await supabase
    .from("promo_codes")
    .delete()
    .eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "delete", "promo_codes", id, {});

  revalidatePath("/admin/marketing/promo-codes");
  redirect("/admin/marketing/promo-codes");
}

// ==============================================
// CAMPAIGN ACTIONS
// ==============================================

export async function createCampaign(formData: FormData) {
  const { userId } = await requireAdmin();
  
  const name = getRequiredString(formData.get("name"), "Name");
  const description = (formData.get("description") as string | null)?.trim() || null;
  const campaignType = getRequiredString(formData.get("campaign_type"), "Campaign type");
  const status = (formData.get("status") as string | null) || "draft";
  
  const startDate = formData.get("start_date") as string | null;
  const endDate = formData.get("end_date") as string | null;
  const promoCodeId = formData.get("promo_code_id") as string | null;

  const payload = {
    name,
    description,
    campaign_type: campaignType,
    status,
    start_date: startDate ? new Date(startDate).toISOString() : null,
    end_date: endDate ? new Date(endDate).toISOString() : null,
    promo_code_id: promoCodeId || null,
    created_by: userId,
  };

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("campaigns")
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  if (data?.id) {
    await logAudit(userId, "create", "campaigns", data.id, payload);
  }

  revalidatePath("/admin/marketing/campaigns");
  redirect("/admin/marketing/campaigns");
}

export async function updateCampaign(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Campaign id");
  
  const name = getRequiredString(formData.get("name"), "Name");
  const description = (formData.get("description") as string | null)?.trim() || null;
  const status = getRequiredString(formData.get("status"), "Status");
  
  const startDate = formData.get("start_date") as string | null;
  const endDate = formData.get("end_date") as string | null;

  const payload = {
    name,
    description,
    status,
    start_date: startDate ? new Date(startDate).toISOString() : null,
    end_date: endDate ? new Date(endDate).toISOString() : null,
    updated_at: new Date().toISOString(),
  };

  const supabase = createAdminClient();
  const { error } = await supabase
    .from("campaigns")
    .update(payload)
    .eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "update", "campaigns", id, payload);

  revalidatePath("/admin/marketing/campaigns");
  revalidatePath(`/admin/marketing/campaigns/${id}`);
  redirect("/admin/marketing/campaigns");
}

export async function deleteCampaign(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Campaign id");
  const confirmValue = formData.get("confirm");
  const confirmed = confirmValue === "on" || confirmValue === "yes";

  if (!confirmed) {
    throw new Error("Delete confirmation required");
  }

  const supabase = createAdminClient();
  const { error } = await supabase
    .from("campaigns")
    .delete()
    .eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "delete", "campaigns", id, {});

  revalidatePath("/admin/marketing/campaigns");
  redirect("/admin/marketing/campaigns");
}

// ==============================================
// PUSH CAMPAIGN ACTIONS
// ==============================================

export async function createPushCampaign(formData: FormData) {
  const { userId } = await requireAdmin();
  
  const title = getRequiredString(formData.get("title"), "Title");
  const message = getRequiredString(formData.get("message"), "Message");
  const targetSegment = getRequiredString(formData.get("target_segment"), "Target segment");
  
  const campaignId = formData.get("campaign_id") as string | null;
  const scheduledAt = formData.get("scheduled_at") as string | null;

  const payload = {
    campaign_id: campaignId || null,
    title,
    message,
    target_segment: targetSegment,
    scheduled_at: scheduledAt ? new Date(scheduledAt).toISOString() : null,
    created_by: userId,
  };

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("push_campaigns")
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  if (data?.id) {
    await logAudit(userId, "create", "push_campaigns", data.id, payload);
  }

  revalidatePath("/admin/marketing/campaigns");
  redirect("/admin/marketing/campaigns");
}

export async function sendPushCampaignNow(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Push campaign id");
  const targetSegment = getRequiredString(formData.get("target_segment"), "Target segment");

  const supabase = createAdminClient();
  const { data, error } = await supabase.rpc("send_push_campaign", {
    p_campaign_id: id,
    p_user_segment: targetSegment,
  });

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "update", "push_campaigns", id, { action: "sent", target_segment: targetSegment });

  revalidatePath("/admin/marketing/campaigns");
  return { success: true, data };
}
