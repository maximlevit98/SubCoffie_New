import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { CafeStatusBadge } from '@/components/CafeStatusBadge';

export default async function CafesListPage() {
  const { userId } = await getUserRole();

  if (!userId) {
    redirect('/login');
  }

  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar
        currentContext="account"
        cafesCount={cafes?.length || 0}
      />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          <div className="mb-6 flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-zinc-900">
                Мои кофейни
              </h1>
              <p className="mt-1 text-sm text-zinc-600">
                Управляйте всеми вашими кофейнями
              </p>
            </div>
            <Link
              href="/admin/owner/cafes/new"
              className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
            >
              <span>+ Создать кофейню</span>
            </Link>
          </div>

          {cafes && cafes.length > 0 ? (
            <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
              {cafes.map((cafe: any) => (
                <div
                  key={cafe.id}
                  className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm"
                >
                  <div className="mb-4 flex items-start justify-between">
                    <div className="flex-1">
                      <h3 className="mb-2 font-semibold text-zinc-900">
                        {cafe.name}
                      </h3>
                      <CafeStatusBadge
                        cafeId={cafe.id}
                        currentStatus={cafe.status}
                      />
                    </div>
                  </div>

                  <div className="mb-4 space-y-2 text-sm text-zinc-600">
                    <div className="flex items-start gap-2">
                      <span>📍</span>
                      <span>{cafe.address || 'Адрес не указан'}</span>
                    </div>
                    {cafe.phone && (
                      <div className="flex items-center gap-2">
                        <span>📞</span>
                        <span>{cafe.phone}</span>
                      </div>
                    )}
                  </div>

                  <div className="space-y-2">
                    <Link
                      href={`/admin/owner/cafe/${cafe.id}/dashboard`}
                      className="block w-full rounded-lg bg-blue-600 px-4 py-2 text-center text-sm font-medium text-white hover:bg-blue-700"
                    >
                      Открыть панель
                    </Link>
                    <div className="flex gap-2">
                      <Link
                        href={`/admin/owner/cafes/${cafe.id}`}
                        className="flex-1 rounded-lg border border-zinc-200 px-4 py-2 text-center text-sm font-medium text-zinc-700 hover:bg-zinc-50"
                      >
                        Редактировать
                      </Link>
                      <Link
                        href={`/admin/owner/cafe/${cafe.id}/publication`}
                        className="flex-1 rounded-lg border border-zinc-200 px-4 py-2 text-center text-sm font-medium text-zinc-700 hover:bg-zinc-50"
                      >
                        Публикация
                      </Link>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="rounded-lg border border-dashed border-zinc-300 bg-white p-12 text-center">
              <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-zinc-100">
                <span className="text-4xl">☕</span>
              </div>
              <h3 className="mb-2 text-lg font-semibold text-zinc-900">
                У вас пока нет кофеен
              </h3>
              <p className="mb-6 text-sm text-zinc-600">
                Создайте свою первую кофейню, чтобы начать принимать заказы
              </p>
              <Link
                href="/admin/owner/cafes/new"
                className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-6 py-3 text-sm font-medium text-white hover:bg-blue-700"
              >
                <span>+ Создать кофейню</span>
              </Link>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
