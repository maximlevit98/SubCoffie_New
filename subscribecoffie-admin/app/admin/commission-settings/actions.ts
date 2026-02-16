'use server';

import { revalidatePath } from 'next/cache';

import { getUserRole } from '@/lib/supabase/roles';
import { createServerClient } from '@/lib/supabase/server';

async function assertAdmin() {
  const { role, userId } = await getUserRole();
  if (!userId || role !== 'admin') {
    throw new Error('Admin role required');
  }
}

function parsePercent(raw: FormDataEntryValue | null): number {
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0 || value > 100) {
    throw new Error('Commission/bonus percent must be between 0 and 100');
  }
  return value;
}

export async function updateCommissionPolicyAction(formData: FormData) {
  await assertAdmin();

  const operationType = String(formData.get('operation_type') || '').trim();
  if (!operationType) {
    throw new Error('operation_type is required');
  }

  const commissionPercent = parsePercent(formData.get('commission_percent'));

  const supabase = await createServerClient();
  const { error } = await supabase
    .from('commission_config')
    .update({
      commission_percent: commissionPercent,
      updated_at: new Date().toISOString(),
    })
    .eq('operation_type', operationType);

  if (error) {
    throw new Error(`Failed to update commission policy: ${error.message}`);
  }

  revalidatePath('/admin/commission-settings');
  revalidatePath('/admin/payments');
  revalidatePath('/admin/owner/finances');
}

export async function updateLoyaltyBonusAction(formData: FormData) {
  await assertAdmin();

  const levelId = String(formData.get('level_id') || '').trim();
  if (!levelId) {
    throw new Error('level_id is required');
  }

  const cashbackPercent = parsePercent(formData.get('cashback_percent'));

  const supabase = await createServerClient();
  const { error } = await supabase
    .from('loyalty_levels')
    .update({
      cashback_percent: cashbackPercent,
      updated_at: new Date().toISOString(),
    })
    .eq('id', levelId);

  if (error) {
    throw new Error(`Failed to update bonus settings: ${error.message}`);
  }

  revalidatePath('/admin/commission-settings');
  revalidatePath('/admin/loyalty');
}
