import { createServerClient as createSupabaseServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabasePublishableKey =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

type CookieMode = "read" | "write";

export async function createServerClient(
  options: { cookieMode?: CookieMode } = {},
) {
  if (!supabaseUrl || !supabasePublishableKey) {
    throw new Error(
      "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (or NEXT_PUBLIC_SUPABASE_ANON_KEY)",
    );
  }

  const cookieStore = await cookies();

  const cookieMode = options.cookieMode ?? "read";
  const canWriteCookies = cookieMode === "write";

  return createSupabaseServerClient(supabaseUrl, supabasePublishableKey, {
    cookies: {
      get(name) {
        return cookieStore.get(name)?.value;
      },
      set(name, value, options) {
        if (!canWriteCookies) {
          return;
        }
        cookieStore.set({ name, value, ...options });
      },
      remove(name, options) {
        if (!canWriteCookies) {
          return;
        }
        cookieStore.set({ name, value: "", ...options, maxAge: 0 });
      },
    },
  });
}
