"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createAdminClient } from "../../../lib/supabase/admin";
import { requireAdmin } from "../../../lib/supabase/roles";

type MenuItemPayload = {
  cafe_id: string;
  category: string;
  name: string;
  description?: string | null;
  price_credits?: number | null;
  sort_order?: number | null;
  is_available?: boolean | null;
};

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

const buildPayload = (formData: FormData): MenuItemPayload => {
  const cafe_id = getRequiredString(formData.get("cafe_id"), "Cafe");
  const category = getRequiredString(formData.get("category"), "Category");
  const name = getRequiredString(formData.get("name"), "Name");
  const rawDescription = (formData.get("description") as string | null)?.trim() ?? "";
  const rawPrice = parseNumber(formData.get("price_credits"));
  const rawSortOrder = parseNumber(formData.get("sort_order"));

  return {
    cafe_id,
    category,
    name,
    description: rawDescription || "—",
    price_credits: rawPrice ?? 0,
    sort_order: rawSortOrder ?? 0,
    is_available: formData.get("is_available") !== "off",
  };
};

const logAudit = async (
  actorUserId: string,
  action: "create" | "update" | "delete",
  recordId: string,
  payload: Record<string, unknown>,
) => {
  const supabase = createAdminClient();
  const { error } = await supabase.from("audit_logs").insert({
    actor_user_id: actorUserId,
    action,
    table_name: "menu_items",
    record_id: recordId,
    payload,
  });

  if (error) {
    throw new Error(error.message);
  }
};

export async function createMenuItem(formData: FormData) {
  const { userId } = await requireAdmin();
  const payload = buildPayload(formData);
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("menu_items")
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  if (data?.id) {
    await logAudit(userId, "create", data.id, payload);
  }

  revalidatePath("/admin/menu-items");
  redirect("/admin/menu-items");
}

export async function updateMenuItem(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Menu item id");
  const payload = buildPayload(formData);
  const supabase = createAdminClient();
  const { error } = await supabase
    .from("menu_items")
    .update(payload)
    .eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "update", id, payload);

  revalidatePath("/admin/menu-items");
  redirect("/admin/menu-items");
}

export async function deleteMenuItem(formData: FormData) {
  const { userId } = await requireAdmin();
  const id = getRequiredString(formData.get("id"), "Menu item id");
  const confirmValue = formData.get("confirm");
  const confirmed = confirmValue === "on" || confirmValue === "yes";

  if (!confirmed) {
    throw new Error("Delete confirmation required");
  }

  const supabase = createAdminClient();
  const { error } = await supabase.from("menu_items").delete().eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logAudit(userId, "delete", id, {});

  revalidatePath("/admin/menu-items");
  redirect("/admin/menu-items");
}

export async function updateMenuItemPrice(
  id: string,
  priceCredits: number | null,
): Promise<{ ok: boolean; error?: string }> {
  "use server";

  const { userId } = await requireAdmin();

  if (!id) {
    return { ok: false, error: "Menu item id is required" };
  }

  const supabase = createAdminClient();
  const { error } = await supabase
    .from("menu_items")
    .update({ price_credits: priceCredits })
    .eq("id", id);

  if (error) {
    return { ok: false, error: error.message };
  }

  await logAudit(userId, "update", id, { price_credits: priceCredits });

  revalidatePath("/admin/menu-items");
  return { ok: true };
}
