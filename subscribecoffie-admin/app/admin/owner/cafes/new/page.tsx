import { OwnerSidebar } from '@/components/OwnerSidebar';
import { createServerClient } from '@/lib/supabase/server';
import { CafeCreationForm } from './CafeCreationForm';

export default async function NewCafePage() {
  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar
        currentContext="account"
        cafesCount={cafes?.length || 0}
      />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-4xl">
          <div className="mb-6">
            <h1 className="text-2xl font-bold text-zinc-900">
              Создать новую кофейню
            </h1>
            <p className="mt-1 text-sm text-zinc-600">
              Заполните информацию о вашей кофейне в 4 простых шага
            </p>
          </div>
          <CafeCreationForm />
        </div>
      </main>
    </div>
  );
}
