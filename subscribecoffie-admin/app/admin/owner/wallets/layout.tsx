import { OwnerSidebar } from "@/components/OwnerSidebar";
import { createServerClient } from "@/lib/supabase/server";

export default async function OwnerWalletsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc("get_owner_cafes");
  const cafesCount = cafes?.length || 0;

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="account" cafesCount={cafesCount} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">{children}</div>
      </main>
    </div>
  );
}
