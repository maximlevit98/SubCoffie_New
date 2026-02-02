import { createServerClient } from '@/lib/supabase/server';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { redirect } from 'next/navigation';
import { getUserRole } from '@/lib/supabase/roles';
import Link from 'next/link';
import { MenuItemsTable } from './MenuItemsTable';
import { Breadcrumbs } from '@/components/Breadcrumbs';

type PageProps = {
  params: Promise<{ cafeId: string }>;
};

export default async function CafeMenuPage({ params }: PageProps) {
  const { cafeId } = await params;
  const { userId, role } = await getUserRole();

  if (!userId || role !== 'owner') {
    redirect('/login');
  }

  const supabase = await createServerClient();

  // Get cafe info
  const { data: cafe } = await supabase
    .from('cafes')
    .select('id, name, account_id')
    .eq('id', cafeId)
    .single();

  if (!cafe) {
    redirect('/admin/owner/dashboard');
  }

  // Verify ownership
  const { data: account } = await supabase
    .from('accounts')
    .select('id')
    .eq('id', cafe.account_id)
    .eq('owner_user_id', userId)
    .single();

  if (!account) {
    redirect('/admin/owner/dashboard');
  }

  // Get all cafes for sidebar
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  // Get menu items
  const { data: menuItems } = await supabase
    .from('menu_items')
    .select('*')
    .eq('cafe_id', cafeId)
    .order('category', { ascending: true })
    .order('sort_order', { ascending: true });

  const categoryLabels: Record<string, string> = {
    drinks: 'Напитки',
    food: 'Еда',
    syrups: 'Сиропы',
    merch: 'Мерч',
  };

  // Group by category
  const groupedItems: Record<string, any[]> = {
    drinks: [],
    food: [],
    syrups: [],
    merch: [],
  };

  menuItems?.forEach((item) => {
    if (groupedItems[item.category]) {
      groupedItems[item.category].push(item);
    }
  });

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar
        currentContext="cafe"
        cafeId={cafeId}
        cafesCount={cafes?.length || 0}
      />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          {/* Breadcrumbs */}
          <Breadcrumbs
            items={[
              { label: 'Главная', href: '/admin/owner/dashboard' },
              { label: 'Мои кофейни', href: '/admin/owner/cafes' },
              {
                label: cafe.name,
                href: `/admin/owner/cafe/${cafeId}/dashboard`,
              },
              { label: 'Меню' },
            ]}
          />

          {/* Header */}
          <div className="mb-6 flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-zinc-900">Меню кофейни</h1>
              <p className="mt-1 text-sm text-zinc-600">{cafe.name}</p>
            </div>
            <Link
              href={`/admin/owner/cafe/${cafeId}/menu/new`}
              className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
            >
              + Добавить позицию
            </Link>
          </div>

          {/* Stats */}
          <div className="mb-6 grid grid-cols-4 gap-4">
            {Object.entries(groupedItems).map(([category, items]) => (
              <div
                key={category}
                className="rounded-lg border border-zinc-200 bg-white p-4"
              >
                <p className="text-sm text-zinc-600">{categoryLabels[category]}</p>
                <p className="mt-1 text-2xl font-bold text-zinc-900">
                  {items.length}
                </p>
              </div>
            ))}
          </div>

          {/* Menu Items by Category */}
          {Object.entries(groupedItems).map(([category, items]) => (
            <div key={category} className="mb-8">
              <h2 className="mb-4 text-lg font-semibold text-zinc-900">
                {categoryLabels[category]}
              </h2>
              {items.length === 0 ? (
                <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-8 text-center">
                  <p className="text-sm text-zinc-500">
                    Нет позиций в этой категории
                  </p>
                  <Link
                    href={`/admin/owner/cafe/${cafeId}/menu/new?category=${category}`}
                    className="mt-2 inline-block text-sm text-blue-600 hover:text-blue-700"
                  >
                    Добавить первую позицию →
                  </Link>
                </div>
              ) : (
                <MenuItemsTable items={items} cafeId={cafeId} />
              )}
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
