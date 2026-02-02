import { createServerClient } from "../../../lib/supabase/server";
import { getUserRole } from "../../../lib/supabase/roles";
import StopListTable from "./StopListTable";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string }>;
};

export default async function StopListPage({ searchParams }: PageProps) {
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
        <h2 className="text-2xl font-semibold">Стоп-лист</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки данных: {cafesError.message}
        </p>
      </section>
    );
  }

  if (!cafes || cafes.length === 0) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Стоп-лист</h2>
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
    .order("name", { ascending: true });

  const selectedCafe = cafes.find((c: any) => c.id === selectedCafeId);

  if (menuError) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Стоп-лист</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки меню: {menuError.message}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      {/* Header with Cafe Selector */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-semibold">🚫 Стоп-лист</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Управление доступностью позиций меню
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
            window.location.href = `/cafe-owner/stop-list?cafe_id=${value}`;
          }}
        >
          {cafes.map((cafe: any) => (
            <option key={cafe.id} value={cafe.id}>
              {cafe.name}
            </option>
          ))}
        </select>
      </div>

      {/* Info Banner */}
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-4">
        <div className="flex gap-3">
          <div className="text-2xl">💡</div>
          <div className="flex-1">
            <p className="text-sm font-medium text-blue-900">
              Как использовать стоп-лист
            </p>
            <p className="mt-1 text-sm text-blue-700">
              Отключайте позиции, которые временно недоступны (закончились
              ингредиенты, технические проблемы). Клиенты не смогут заказать
              отключенные позиции.
            </p>
          </div>
        </div>
      </div>

      {/* Statistics */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <p className="text-sm text-zinc-600">Всего позиций</p>
          <p className="mt-2 text-3xl font-bold">{menuItems?.length || 0}</p>
        </div>
        <div className="rounded-lg border border-green-200 bg-green-50 p-6">
          <p className="text-sm text-zinc-600">Доступно</p>
          <p className="mt-2 text-3xl font-bold text-green-700">
            {menuItems?.filter((item) => item.is_active).length || 0}
          </p>
        </div>
        <div className="rounded-lg border border-red-200 bg-red-50 p-6">
          <p className="text-sm text-zinc-600">В стоп-листе</p>
          <p className="mt-2 text-3xl font-bold text-red-700">
            {menuItems?.filter((item) => !item.is_active).length || 0}
          </p>
        </div>
      </div>

      {/* Stop List Table */}
      <StopListTable menuItems={menuItems || []} cafeId={selectedCafeId} />
    </section>
  );
}
