import { OwnerSidebar } from '@/components/OwnerSidebar';
import { createServerClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

export default async function EditCafePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  const cafe = cafes?.find((c: any) => c.id === id);
  if (!cafe) {
    redirect('/admin/owner/cafes');
  }

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar
        currentContext="account"
        cafesCount={cafes?.length || 0}
      />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-4xl">
          <h1 className="mb-6 text-2xl font-bold text-zinc-900">
            Редактировать кофейню: {cafe.name}
          </h1>
          <div className="rounded-lg border border-zinc-200 bg-white p-8">
            <p className="text-zinc-600">
              Форма редактирования базовой информации о кофейне (coming soon...)
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}
