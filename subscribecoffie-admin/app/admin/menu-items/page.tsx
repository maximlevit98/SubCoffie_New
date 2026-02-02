import Link from "next/link";

import { listCafes } from "../../../lib/supabase/queries/cafes";
import { listMenuItems } from "../../../lib/supabase/queries/menu-items";
import { getUserRole } from "../../../lib/supabase/roles";
import MenuItemsTable from "./MenuItemsTable";

type MenuItemsPageProps = {
  searchParams?: Promise<{
    cafe_id?: string;
  }>;
};

export default async function MenuItemsPage({
  searchParams,
}: MenuItemsPageProps) {
  const resolvedParams = await searchParams;
  const cafeId = resolvedParams?.cafe_id?.trim() ?? "";
  const [{ data: cafes }, { data: items, error }, { role }] =
    await Promise.all([
      listCafes(),
      listMenuItems(cafeId || undefined),
      getUserRole(),
    ]);
  const isAdmin = role === "admin";

  const retryHref = cafeId
    ? `/admin/menu-items?cafe_id=${encodeURIComponent(cafeId)}`
    : "/admin/menu-items";

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">🍽️ Управление меню</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить меню: {error}
        </p>
        <Link
          href={retryHref}
          className="inline-flex items-center rounded border border-zinc-300 px-3 py-2 text-sm hover:bg-zinc-50"
        >
          Retry
        </Link>
      </section>
    );
  }

  // Группируем по кофейням
  const cafeMap = new Map((cafes ?? []).map((cafe) => [cafe.id, cafe]));
  const itemsByCafe = new Map<string, typeof items>();
  
  (items ?? []).forEach((item) => {
    if (!itemsByCafe.has(item.cafe_id)) {
      itemsByCafe.set(item.cafe_id, []);
    }
    itemsByCafe.get(item.cafe_id)?.push(item);
  });

  const selectedCafe = cafeId && cafeMap.get(cafeId);

  return (
    <section className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-3">
            <h2 className="text-2xl font-semibold">🍽️ Управление меню</h2>
            {selectedCafe && (
              <Link
                href={`/admin/cafes/${cafeId}`}
                className="rounded border border-zinc-300 bg-white px-3 py-1 text-xs font-medium hover:bg-zinc-50"
              >
                ← К кофейне
              </Link>
            )}
          </div>
          <p className="mt-1 text-sm text-zinc-600">
            {selectedCafe
              ? `Меню кофейни "${selectedCafe.name}"`
              : `Всего позиций: ${items?.length ?? 0} в ${itemsByCafe.size} кофейнях`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-sm text-emerald-600">Supabase: OK</span>
          {isAdmin && (
            <Link
              href="/admin/menu-items/new"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              ➕ Добавить позицию
            </Link>
          )}
        </div>
      </div>

      {/* Фильтр по кофейням */}
      <div className="rounded-lg border border-zinc-200 bg-white p-4">
        <form action="/admin/menu-items" method="get" className="space-y-3">
          <label className="block text-sm font-medium text-zinc-700">
            Фильтр по кофейне
          </label>
          <div className="flex items-center gap-3">
            <select
              name="cafe_id"
              defaultValue={cafeId}
              className="flex-1 rounded border border-zinc-300 px-3 py-2 text-sm"
            >
              <option value="">🏪 Все кофейни ({itemsByCafe.size})</option>
              {(cafes ?? []).map((cafe) => {
                const count = itemsByCafe.get(cafe.id)?.length ?? 0;
                return (
                  <option key={cafe.id} value={cafe.id}>
                    {cafe.name} ({count} позиций)
                  </option>
                );
              })}
            </select>
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              Применить
            </button>
            {cafeId && (
              <Link
                href="/admin/menu-items"
                className="rounded border border-zinc-300 px-4 py-2 text-sm hover:bg-zinc-50"
              >
                Сбросить
              </Link>
            )}
          </div>
        </form>
      </div>

      {/* Таблица или группировка */}
      {!cafeId && itemsByCafe.size > 0 ? (
        <div className="space-y-4">
          {Array.from(itemsByCafe.entries()).map(([cafeId, cafeItems]) => {
            const cafe = cafeMap.get(cafeId);
            return (
              <div key={cafeId} className="rounded-lg border border-zinc-200 bg-white p-5">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3">
                      <h3 className="text-lg font-semibold text-zinc-900">
                        {cafe?.name ?? "Неизвестная кофейня"}
                      </h3>
                      <span className="rounded-full bg-zinc-100 px-2.5 py-0.5 text-xs font-medium text-zinc-700">
                        {cafeItems?.length ?? 0} позиций
                      </span>
                    </div>
                    <p className="mt-1 text-sm text-zinc-600">
                      📍 {cafe?.address ?? "Адрес не указан"}
                    </p>
                    <div className="mt-2 flex items-center gap-4 text-xs text-zinc-500">
                      <span>⭐ Рейтинг: {cafe?.rating ?? "—"}</span>
                      <span>💰 Средний чек: {cafe?.avg_check_credits ?? "—"}₽</span>
                      <span>⏱️ ETA: {cafe?.eta_minutes ?? "—"} мин</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Link
                      href={`/admin/cafes/${cafeId}`}
                      className="rounded border border-zinc-300 bg-white px-3 py-1.5 text-xs font-medium hover:bg-zinc-50"
                    >
                      Редактировать кофейню
                    </Link>
                    <Link
                      href={`/admin/menu-items?cafe_id=${cafeId}`}
                      className="rounded border border-blue-300 bg-blue-50 px-4 py-1.5 text-xs font-medium text-blue-700 hover:bg-blue-100"
                    >
                      Управлять меню →
                    </Link>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <MenuItemsTable items={items ?? []} canEdit={isAdmin} cafeId={cafeId} />
      )}

      {/* Пустое состояние */}
      {items?.length === 0 && (
        <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-12 text-center">
          <p className="text-lg font-medium text-zinc-900">
            Меню пусто
          </p>
          <p className="mt-2 text-sm text-zinc-600">
            {cafeId
              ? "Добавьте первую позицию в меню этой кофейни"
              : "Начните с добавления позиций в меню"}
          </p>
          {isAdmin && (
            <Link
              href="/admin/menu-items/new"
              className="mt-4 inline-flex items-center rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              ➕ Добавить позицию
            </Link>
          )}
        </div>
      )}
    </section>
  );
}
