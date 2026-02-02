import { createServerClient } from '@/lib/supabase/server';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { redirect } from 'next/navigation';
import { getUserRole } from '@/lib/supabase/roles';
import { MenuItemForm } from '../new/MenuItemForm';

type PageProps = {
  params: Promise<{ cafeId: string; itemId: string }>;
};

export default async function EditMenuItemPage({ params }: PageProps) {
  const { cafeId, itemId } = await params;
  const { userId, role } = await getUserRole();

  if (!userId || role !== 'owner') {
    redirect('/login');
  }

  const supabase = await createServerClient();

  // Get cafe info and verify ownership
  const { data: cafe } = await supabase
    .from('cafes')
    .select('id, name, account_id')
    .eq('id', cafeId)
    .single();

  if (!cafe) {
    redirect('/admin/owner/dashboard');
  }

  const { data: account } = await supabase
    .from('accounts')
    .select('id')
    .eq('id', cafe.account_id)
    .eq('owner_user_id', userId)
    .single();

  if (!account) {
    redirect('/admin/owner/dashboard');
  }

  // Get menu item
  const { data: menuItem } = await supabase
    .from('menu_items')
    .select('*')
    .eq('id', itemId)
    .eq('cafe_id', cafeId)
    .single();

  if (!menuItem) {
    redirect(`/admin/owner/cafe/${cafeId}/menu`);
  }

  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar
        currentContext="cafe"
        cafeId={cafeId}
        cafesCount={cafes?.length || 0}
      />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-2xl">
          <div className="mb-6">
            <h1 className="text-2xl font-bold text-zinc-900">
              Редактировать позицию
            </h1>
            <p className="mt-1 text-sm text-zinc-600">{cafe.name}</p>
          </div>
          <MenuItemForm cafeId={cafeId} initialData={{ ...menuItem, id: menuItem.id }} />
        </div>
      </main>
    </div>
  );
}
