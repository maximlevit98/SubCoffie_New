"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createAdminClient } from "../../../lib/supabase/admin";

export async function createRegion(formData: FormData) {
  const supabase = createAdminClient();

  const name = formData.get("name") as string;
  const city = formData.get("city") as string;
  const country = formData.get("country") as string;
  const timezone = formData.get("timezone") as string;
  const latitude = formData.get("latitude") as string;
  const longitude = formData.get("longitude") as string;

  const { data, error } = await supabase.rpc("create_region", {
    p_name: name,
    p_city: city,
    p_country: country || "Russia",
    p_timezone: timezone || "Europe/Moscow",
    p_latitude: latitude ? parseFloat(latitude) : null,
    p_longitude: longitude ? parseFloat(longitude) : null,
  });

  if (error) {
    console.error("Error creating region:", error);
    throw new Error(error.message);
  }

  revalidatePath("/admin/regions");
  return data;
}

export async function updateRegion(formData: FormData) {
  const supabase = createAdminClient();

  const regionId = formData.get("region_id") as string;
  const name = formData.get("name") as string;
  const isActive = formData.get("is_active") === "true";
  const timezone = formData.get("timezone") as string;
  const latitude = formData.get("latitude") as string;
  const longitude = formData.get("longitude") as string;

  const { error } = await supabase.rpc("update_region", {
    p_region_id: regionId,
    p_name: name || null,
    p_is_active: isActive,
    p_timezone: timezone || null,
    p_latitude: latitude ? parseFloat(latitude) : null,
    p_longitude: longitude ? parseFloat(longitude) : null,
  });

  if (error) {
    console.error("Error updating region:", error);
    throw new Error(error.message);
  }

  revalidatePath("/admin/regions");
  revalidatePath(`/admin/regions/${regionId}`);
}

export async function assignCafeToRegion(formData: FormData) {
  const supabase = createAdminClient();

  const cafeId = formData.get("cafe_id") as string;
  const regionId = formData.get("region_id") as string;

  const { error } = await supabase.rpc("assign_cafe_to_region", {
    p_cafe_id: cafeId,
    p_region_id: regionId,
  });

  if (error) {
    console.error("Error assigning cafe to region:", error);
    throw new Error(error.message);
  }

  revalidatePath(`/admin/regions/${regionId}`);
}

export async function removeCafeFromRegion(formData: FormData) {
  const supabase = createAdminClient();

  const cafeId = formData.get("cafe_id") as string;
  const regionId = formData.get("region_id") as string;

  const { error } = await supabase.rpc("remove_cafe_from_region", {
    p_cafe_id: cafeId,
    p_region_id: regionId,
  });

  if (error) {
    console.error("Error removing cafe from region:", error);
    throw new Error(error.message);
  }

  revalidatePath(`/admin/regions/${regionId}`);
}
