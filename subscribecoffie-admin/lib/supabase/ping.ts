import { createAdminClient } from "./admin";

export async function pingSupabase(): Promise<{
  ok: boolean;
  error?: string;
}> {
  try {
    const supabase = createAdminClient();
    const { error } = await supabase.from("cafes").select("id").limit(1);

    if (error) {
      return { ok: false, error: error.message };
    }

    return { ok: true };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : "Unknown error",
    };
  }
}
