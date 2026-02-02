import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { redirect } from 'next/navigation';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { CafeSwitcher } from '@/components/CafeSwitcher';

export default async function CafeSettingsPage({
  params,
}: {
  params: Promise<{ cafeId: string }>;
}) {
  const { userId } = await getUserRole();
  const { cafeId } = await params;

  if (!userId) {
    redirect('/login');
  }

  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  const ownsCafe = cafes?.some((cafe: any) => cafe.id === cafeId);
  if (!ownsCafe) {
    redirect('/admin/owner/dashboard');
  }

  const { data: cafe } = await supabase
    .from('cafes')
    .select('*')
    .eq('id', cafeId)
    .single();

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="cafe" cafeId={cafeId} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          <div className="mb-6 flex items-center justify-between">
            <h1 className="text-2xl font-bold text-zinc-900">
              Настройки - {cafe?.name}
            </h1>
            <CafeSwitcher currentCafeId={cafeId} cafes={cafes || []} />
          </div>
          <div className="rounded-lg border border-zinc-200 bg-white p-8 text-center">
            <p className="text-zinc-600">
              Настройки кофейни (график работы, контакты) (coming soon...)
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}
