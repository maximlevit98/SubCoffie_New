"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createAdminClient } from "../../../lib/supabase/admin";

export async function createFranchisePartner(formData: FormData) {
  const supabase = createAdminClient();

  const userId = formData.get("user_id") as string;
  const companyName = formData.get("company_name") as string;
  const contactPerson = formData.get("contact_person") as string;
  const email = formData.get("email") as string;
  const phone = formData.get("phone") as string;
  const taxId = formData.get("tax_id") as string;
  const commissionRate = formData.get("commission_rate") as string;

  const { data, error } = await supabase.rpc("create_franchise_partner", {
    p_user_id: userId,
    p_company_name: companyName,
    p_contact_person: contactPerson,
    p_email: email,
    p_phone: phone,
    p_tax_id: taxId || null,
    p_commission_rate: commissionRate ? parseFloat(commissionRate) : 10.0,
  });

  if (error) {
    console.error("Error creating franchise partner:", error);
    throw new Error(error.message);
  }

  revalidatePath("/admin/franchise");
  return data;
}

export async function updateFranchisePartner(formData: FormData) {
  const supabase = createAdminClient();

  const franchiseId = formData.get("franchise_id") as string;
  const companyName = formData.get("company_name") as string;
  const contactPerson = formData.get("contact_person") as string;
  const email = formData.get("email") as string;
  const phone = formData.get("phone") as string;
  const taxId = formData.get("tax_id") as string;
  const commissionRate = formData.get("commission_rate") as string;
  const status = formData.get("status") as string;
  const notes = formData.get("notes") as string;

  const { error } = await supabase.rpc("update_franchise_partner", {
    p_franchise_id: franchiseId,
    p_company_name: companyName || null,
    p_contact_person: contactPerson || null,
    p_email: email || null,
    p_phone: phone || null,
    p_tax_id: taxId || null,
    p_commission_rate: commissionRate ? parseFloat(commissionRate) : null,
    p_status: status || null,
    p_notes: notes || null,
  });

  if (error) {
    console.error("Error updating franchise partner:", error);
    throw new Error(error.message);
  }

  revalidatePath("/admin/franchise");
  revalidatePath(`/admin/franchise/${franchiseId}`);
}
