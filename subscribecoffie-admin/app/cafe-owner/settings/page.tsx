import { createServerClient } from "../../../lib/supabase/server";
import { getUserRole } from "../../../lib/supabase/roles";

type PageProps = {
  searchParams: Promise<{ cafe_id?: string }>;
};

export default async function CafeOwnerSettingsPage({
  searchParams,
}: PageProps) {
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
        <h2 className="text-2xl font-semibold">Настройки</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка загрузки данных: {cafesError.message}
        </p>
      </section>
    );
  }

  if (!cafes || cafes.length === 0) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Настройки</h2>
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

  // Fetch cafe details
  const { data: cafe } = await supabase
    .from("cafes")
    .select("*")
    .eq("id", selectedCafeId)
    .single();

  return (
    <section className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-semibold">⚙️ Настройки</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Управление параметрами кафе
          </p>
        </div>
        <select
          className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          value={selectedCafeId}
          onChange={(e) => {
            const value = e.target.value;
            window.location.href = `/cafe-owner/settings?cafe_id=${value}`;
          }}
        >
          {cafes.map((c: any) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </div>

      {/* Basic Info */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="mb-4 text-lg font-semibold">Основная информация</h3>
        <div className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-zinc-700">
              Название
            </label>
            <input
              type="text"
              value={cafe?.name || ""}
              disabled
              className="w-full rounded-lg border border-zinc-300 bg-zinc-50 px-4 py-2 text-sm"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-zinc-700">
              Адрес
            </label>
            <input
              type="text"
              value={cafe?.address || ""}
              disabled
              className="w-full rounded-lg border border-zinc-300 bg-zinc-50 px-4 py-2 text-sm"
            />
          </div>
          <p className="text-sm text-zinc-500">
            💡 Для изменения основной информации обратитесь к администратору
          </p>
        </div>
      </div>

      {/* Operational Settings */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="mb-4 text-lg font-semibold">Операционные настройки</h3>
        <div className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-zinc-700">
              Статус работы
            </label>
            <div className="flex gap-3">
              <span
                className={`rounded-lg px-4 py-2 text-sm font-medium ${
                  cafe?.mode === "open"
                    ? "bg-green-100 text-green-800"
                    : "bg-zinc-100 text-zinc-600"
                }`}
              >
                {cafe?.mode === "open" ? "✅ Открыто" : ""}
                {cafe?.mode === "busy" ? "⏳ Занято" : ""}
                {cafe?.mode === "paused" ? "⏸️ Приостановлено" : ""}
                {cafe?.mode === "closed" ? "🚫 Закрыто" : ""}
              </span>
            </div>
            <p className="mt-2 text-sm text-zinc-500">
              💡 Для изменения статуса обратитесь к администратору
            </p>
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <label className="mb-1 block text-sm font-medium text-zinc-700">
                ETA (минут)
              </label>
              <input
                type="number"
                value={cafe?.eta_minutes || ""}
                disabled
                className="w-full rounded-lg border border-zinc-300 bg-zinc-50 px-4 py-2 text-sm"
              />
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-zinc-700">
                Макс. активных заказов
              </label>
              <input
                type="number"
                value={cafe?.max_active_orders || ""}
                disabled
                className="w-full rounded-lg border border-zinc-300 bg-zinc-50 px-4 py-2 text-sm"
              />
            </div>
          </div>
          <div>
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={cafe?.supports_citypass || false}
                disabled
                className="h-4 w-4 rounded border-zinc-300"
              />
              <span className="text-sm text-zinc-700">
                Поддержка CityPass
              </span>
            </label>
          </div>
        </div>
      </div>

      {/* Quick Links */}
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-6">
        <h3 className="mb-3 text-lg font-semibold text-blue-900">
          Полезные ссылки
        </h3>
        <div className="space-y-2 text-sm text-blue-800">
          <p>
            • <strong>Техническая поддержка:</strong> support@subscribecoffie.com
          </p>
          <p>
            • <strong>Документация:</strong> docs.subscribecoffie.com
          </p>
          <p>
            • <strong>Служба поддержки:</strong> +7 (XXX) XXX-XX-XX
          </p>
        </div>
      </div>
    </section>
  );
}
