import Link from "next/link";
import { redirect } from "next/navigation";

import { createAdminClient } from "../../../../lib/supabase/admin";
import { listCafes } from "../../../../lib/supabase/queries/cafes";
import { getUserRole } from "../../../../lib/supabase/roles";
import { deleteMenuItem, updateMenuItem } from "../actions";

const CATEGORY_OPTIONS = [
  { value: "drinks", label: "☕ Напитки", description: "Кофе, чай, смузи" },
  { value: "food", label: "🥐 Еда", description: "Выпечка, сэндвичи, десерты" },
  { value: "syrups", label: "🍯 Сиропы", description: "Добавки к напиткам" },
  { value: "merch", label: "🎁 Мерч", description: "Товары и сувениры" },
] as const;

type MenuItemPageProps = {
  params: Promise<{
    id: string;
  }>;
};

export default async function MenuItemPage({ params }: MenuItemPageProps) {
  const { role } = await getUserRole();
  const resolvedParams = await params;

  if (role !== "admin") {
    redirect("/admin/menu-items");
  }

  const supabase = createAdminClient();
  const [{ data, error }, { data: cafes }] = await Promise.all([
    supabase.from("menu_items").select("*").eq("id", resolvedParams.id).maybeSingle(),
    listCafes(),
  ]);

  if (error || !data) {
    return (
      <section className="mx-auto max-w-3xl space-y-4">
        <div className="flex items-center gap-4">
          <Link
            href="/admin/menu-items"
            className="rounded border border-zinc-300 p-2 hover:bg-zinc-50"
          >
            ← Назад
          </Link>
          <h2 className="text-2xl font-semibold">Позиция меню</h2>
        </div>
        <div className="rounded border border-red-200 bg-red-50 p-4">
          <p className="text-sm text-red-700">
            ❌ Не удалось загрузить позицию: {error?.message ?? "Не найдена"}
          </p>
        </div>
      </section>
    );
  }

  const cafe = (cafes ?? []).find((c) => c.id === data.cafe_id);

  return (
    <section className="mx-auto max-w-3xl space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link
          href="/admin/menu-items"
          className="rounded border border-zinc-300 p-2 hover:bg-zinc-50"
        >
          ← Назад
        </Link>
        <div className="flex-1">
          <h2 className="text-2xl font-semibold">✏️ Редактировать позицию</h2>
          <p className="mt-1 text-sm text-zinc-600">
            {cafe?.name ?? "Неизвестная кофейня"} • {data.name}
          </p>
        </div>
      </div>

      {/* Form */}
      <form action={updateMenuItem} className="space-y-6">
        <input type="hidden" name="id" value={data.id} />

        {/* Секция 1: Основная информация */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold text-zinc-900">
            📋 Основная информация
          </h3>
          <div className="space-y-4">
            {/* Кофейня */}
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-zinc-700">
                Кофейня <span className="text-red-500">*</span>
              </span>
              <select
                name="cafe_id"
                required
                defaultValue={data.cafe_id ?? ""}
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              >
                <option value="">Выберите кофейню</option>
                {(cafes ?? []).map((cafe) => (
                  <option key={cafe.id} value={cafe.id}>
                    {cafe.name ?? cafe.id}
                  </option>
                ))}
              </select>
              <p className="mt-1 text-xs text-zinc-500">
                Изменение кофейни переместит позицию в другое меню
              </p>
            </label>

            {/* Название */}
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-zinc-700">
                Название <span className="text-red-500">*</span>
              </span>
              <input
                type="text"
                name="name"
                required
                defaultValue={data.name ?? ""}
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
            </label>

            {/* Категория */}
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-zinc-700">
                Категория <span className="text-red-500">*</span>
              </span>
              <div className="grid gap-3 sm:grid-cols-2">
                {CATEGORY_OPTIONS.map((category) => (
                  <label
                    key={category.value}
                    className="flex cursor-pointer items-start gap-3 rounded-lg border border-zinc-200 p-4 hover:border-zinc-400 has-[:checked]:border-zinc-900 has-[:checked]:bg-zinc-50"
                  >
                    <input
                      type="radio"
                      name="category"
                      value={category.value}
                      defaultChecked={data.category === category.value}
                      required
                      className="mt-0.5"
                    />
                    <div className="flex-1">
                      <div className="text-sm font-medium text-zinc-900">
                        {category.label}
                      </div>
                      <div className="text-xs text-zinc-500">
                        {category.description}
                      </div>
                    </div>
                  </label>
                ))}
              </div>
            </label>

            {/* Описание */}
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-zinc-700">
                Описание
              </span>
              <textarea
                name="description"
                rows={3}
                defaultValue={data.description ?? ""}
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
            </label>
          </div>
        </div>

        {/* Секция 2: Цена и настройки */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold text-zinc-900">
            💰 Цена и настройки
          </h3>
          <div className="grid gap-4 sm:grid-cols-2">
            {/* Цена */}
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-zinc-700">
                Цена (кредиты)
              </span>
              <input
                type="number"
                name="price_credits"
                step="1"
                min="0"
                defaultValue={data.price_credits ?? ""}
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
            </label>

            {/* Время приготовления */}
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-zinc-700">
                Время приготовления (сек)
              </span>
              <input
                type="number"
                name="prep_time_sec"
                step="1"
                min="0"
                defaultValue={data.prep_time_sec ?? ""}
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
            </label>

            {/* Порядок сортировки */}
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-zinc-700">
                Порядок сортировки
              </span>
              <input
                type="number"
                name="sort_order"
                step="1"
                min="0"
                defaultValue={data.sort_order ?? ""}
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
            </label>

            {/* Доступность */}
            <label className="flex items-start gap-3 rounded-lg border border-zinc-200 p-4">
              <input
                type="checkbox"
                name="is_available"
                defaultChecked={data.is_available ?? true}
                className="mt-0.5"
              />
              <div>
                <div className="text-sm font-medium text-zinc-900">
                  Доступно для заказа
                </div>
                <div className="text-xs text-zinc-500">
                  Позиция отображается в меню
                </div>
              </div>
            </label>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center justify-between rounded-lg border border-zinc-200 bg-zinc-50 p-4">
          <Link
            href="/admin/menu-items"
            className="rounded border border-zinc-300 bg-white px-4 py-2 text-sm font-medium hover:bg-zinc-50"
          >
            Отмена
          </Link>
          <button
            type="submit"
            className="rounded bg-zinc-900 px-6 py-2 text-sm font-medium text-white hover:bg-zinc-800"
          >
            💾 Сохранить изменения
          </button>
        </div>
      </form>

      {/* Delete Section */}
      <form
        action={deleteMenuItem}
        className="rounded-lg border border-red-200 bg-red-50 p-6"
      >
        <input type="hidden" name="id" value={data.id} />
        <h3 className="mb-4 text-lg font-semibold text-red-900">
          🗑️ Удалить позицию
        </h3>
        <p className="mb-4 text-sm text-red-700">
          Удаление позиции необратимо. Все связанные заказы останутся в системе,
          но эта позиция больше не будет доступна для новых заказов.
        </p>
        <div className="flex flex-wrap items-center gap-3">
          <label className="flex items-center gap-2 text-sm text-red-700">
            <input type="checkbox" name="confirm" required />
            Подтверждаю удаление
          </label>
          <button
            type="submit"
            className="rounded bg-red-600 px-6 py-2 text-sm font-medium text-white hover:bg-red-700"
          >
            🗑️ Удалить навсегда
          </button>
        </div>
      </form>
    </section>
  );
}
