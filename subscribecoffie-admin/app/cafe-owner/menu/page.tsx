import Link from "next/link";
import { createServerClient } from "../../../lib/supabase/server";
import { getUserRole } from "../../../lib/supabase/roles";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string }>;
};

export default async function CafeOwnerMenuPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const cafeId = params?.cafe_id;

  const { userId } = await getUserRole();
  const supabase = await createServerClient();

  // Get owner's cafes
  const { data: cafes, error: cafesError } = await supabase.rpc(
    "get_owner_cafes"
  );

  if (cafesError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Меню</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки данных: {cafesError.message}
        </p>
      </section>
    );
  }

  if (!cafes || cafes.length === 0) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Меню</h2>
        <div className="rounded-lg border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <div className="mb-4 text-6xl">☕</div>
          <h3 className="mb-2 text-lg font-semibold">У вас пока нет кафе</h3>
          <p className="text-sm text-zinc-600">
            Обратитесь к администратору для добавления вашего кафе в систему
          </p>
        </div>
      </section>
    );
  }

  // Use first cafe if no cafe selected
  const selectedCafeId = cafeId || cafes[0].id;

  // Fetch menu items
  const { data: menuItems, error: menuError } = await supabase
    .from("menu_items")
    .select("*")
    .eq("cafe_id", selectedCafeId)
    .order("category", { ascending: true })
    .order("sort_order", { ascending: true });

  const selectedCafe = cafes.find((c: any) => c.id === selectedCafeId);

  if (menuError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Меню</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки меню: {menuError.message}
        </p>
      </section>
    );
  }

  const categoryLabels: { [key: string]: string } = {
    drinks: "☕ Напитки",
    food: "🍞 Еда",
    syrups: "🍯 Сиропы",
    merch: "🎁 Товары",
  };

  // Group items by category
  const groupedItems = (menuItems || []).reduce((acc, item) => {
    if (!acc[item.category]) {
      acc[item.category] = [];
    }
    acc[item.category].push(item);
    return acc;
  }, {} as { [key: string]: any[] });

  return (
    <section className="space-y-6">
      {/* Header with Cafe Selector */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-semibold">📋 Меню</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Управление позициями меню
          </p>
          <p className="mt-1 text-sm text-zinc-600">
            {selectedCafe?.name} · {selectedCafe?.address}
          </p>
        </div>
        <select
          className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          value={selectedCafeId}
          onChange={(e) => {
            const value = e.target.value;
            window.location.href = `/cafe-owner/menu?cafe_id=${value}`;
          }}
        >
          {cafes.map((cafe: any) => (
            <option key={cafe.id} value={cafe.id}>
              {cafe.name}
            </option>
          ))}
        </select>
      </div>

      {/* Statistics */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <p className="text-sm text-zinc-600">Всего позиций</p>
          <p className="mt-2 text-2xl font-bold">{menuItems?.length || 0}</p>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <p className="text-sm text-zinc-600">Напитки</p>
          <p className="mt-2 text-2xl font-bold">
            {groupedItems["drinks"]?.length || 0}
          </p>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <p className="text-sm text-zinc-600">Еда</p>
          <p className="mt-2 text-2xl font-bold">
            {groupedItems["food"]?.length || 0}
          </p>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <p className="text-sm text-zinc-600">Другое</p>
          <p className="mt-2 text-2xl font-bold">
            {(groupedItems["syrups"]?.length || 0) +
              (groupedItems["merch"]?.length || 0)}
          </p>
        </div>
      </div>

      {/* Info Banner */}
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-4">
        <div className="flex gap-3">
          <div className="text-2xl">💡</div>
          <div className="flex-1">
            <p className="text-sm font-medium text-blue-900">
              Для добавления новых позиций обратитесь к администратору
            </p>
            <p className="mt-1 text-sm text-blue-700">
              Вы можете управлять доступностью существующих позиций через{" "}
              <Link
                href={`/cafe-owner/stop-list?cafe_id=${selectedCafeId}`}
                className="font-semibold underline"
              >
                Стоп-лист
              </Link>
            </p>
          </div>
        </div>
      </div>

      {/* Menu Items by Category */}
      {Object.entries(groupedItems).map(([category, items]) => (
        <div
          key={category}
          className="rounded-lg border border-zinc-200 bg-white"
        >
          <div className="border-b border-zinc-200 bg-zinc-50 px-6 py-4">
            <h3 className="text-lg font-semibold">
              {categoryLabels[category] || category}
            </h3>
          </div>
          <div className="divide-y divide-zinc-100">
            {items.map((item) => (
              <div key={item.id} className="px-6 py-4">
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3">
                      <h4 className="font-medium text-zinc-900">{item.name}</h4>
                      <span className="text-sm text-zinc-500">
                        {item.price_credits} кр.
                      </span>
                      {item.is_active ? (
                        <span className="rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-800">
                          Доступно
                        </span>
                      ) : (
                        <span className="rounded-full bg-red-100 px-2 py-1 text-xs font-medium text-red-800">
                          Недоступно
                        </span>
                      )}
                    </div>
                    {item.description && (
                      <p className="mt-1 text-sm text-zinc-600">
                        {item.description}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-sm text-zinc-500">
                      Порядок: {item.sort_order}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}

      {menuItems && menuItems.length === 0 && (
        <div className="rounded-lg border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <div className="mb-4 text-6xl">📋</div>
          <h3 className="mb-2 text-lg font-semibold">Меню пока пустое</h3>
          <p className="text-sm text-zinc-600">
            Обратитесь к администратору для добавления позиций меню
          </p>
        </div>
      )}
    </section>
  );
}
