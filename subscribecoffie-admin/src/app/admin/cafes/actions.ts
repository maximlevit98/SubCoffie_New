"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createAdminClient } from "../../../lib/supabase/admin";

type CafePayload = {
  name: string;
  address?: string | null;
  mode?: string | null;
  eta_minutes?: number | null;
  supports_citypass?: boolean | null;
  distance_km?: number | null;
  rating?: number | null;
  avg_check_credits?: number | null;
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

const buildPayload = (formData: FormData): CafePayload => {
  const name = getRequiredString(formData.get("name"), "Name");
  const rating = parseNumber(formData.get("rating"));
  const avgCheck = parseNumber(formData.get("avg_check_credits"));
  const rawAddress = (formData.get("address") as string | null)?.trim() ?? "";
  const rawMode = (formData.get("mode") as string | null)?.trim() ?? "";

  if (rating !== null && (rating < 0 || rating > 5)) {
    throw new Error("Rating must be between 0 and 5");
  }

  if (avgCheck !== null && avgCheck < 0) {
    throw new Error("Avg check must be 0 or higher");
  }

  return {
    name,
    address: rawAddress || "—",
    mode: rawMode || "open",
    eta_minutes: parseNumber(formData.get("eta_minutes")),
    supports_citypass: formData.get("supports_citypass") === "on",
    distance_km: parseNumber(formData.get("distance_km")),
    rating,
    avg_check_credits: avgCheck,
  };
};


export async function createCafe(formData: FormData) {
  const payload = buildPayload(formData);
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("cafes")
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }


  revalidatePath("/admin/cafes");
  redirect("/admin/cafes");
}

export async function updateCafe(formData: FormData) {
  const id = getRequiredString(formData.get("id"), "Cafe id");
  const payload = buildPayload(formData);
  const supabase = createAdminClient();
  const { error } = await supabase.from("cafes").update(payload).eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath("/admin/cafes");
  redirect("/admin/cafes");
}

export async function updateCafeMode(formData: FormData) {
  const id = getRequiredString(formData.get("id"), "Cafe id");
  const mode = getRequiredString(formData.get("mode"), "Mode");
  const supabase = createAdminClient();
  const { error } = await supabase.from("cafes").update({ mode }).eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath("/admin/cafes");
  redirect("/admin/cafes");
}

export async function deleteCafe(formData: FormData) {
  const id = getRequiredString(formData.get("id"), "Cafe id");
  const confirmValue = formData.get("confirm");
  const confirmed = confirmValue === "on" || confirmValue === "yes";

  if (!confirmed) {
    throw new Error("Delete confirmation required");
  }

  const supabase = createAdminClient();
  const { error } = await supabase.from("cafes").delete().eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath("/admin/cafes");
  redirect("/admin/cafes");
}
