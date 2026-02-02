import Link from "next/link";

import { listCafes } from "../../../../lib/supabase/queries/cafes";
import { createMenuItem } from "../actions";

const CATEGORY_OPTIONS = [
  { value: "drinks", label: "☕ Напитки", description: "Кофе, чай, смузи" },
  { value: "food", label: "🥐 Еда", description: "Выпечка, сэндвичи, десерты" },
  { value: "syrups", label: "🍯 Сиропы", description: "Добавки к напиткам" },
  { value: "merch", label: "🎁 Мерч", description: "Товары и сувениры" },
] as const;

type NewMenuItemPageProps = {
  searchParams?: Promise<{
    cafe_id?: string;
  }>;
};

export default async function NewMenuItemPage({
  searchParams,
}: NewMenuItemPageProps) {
  const resolvedParams = await searchParams;
  const preselectedCafeId = resolvedParams?.cafe_id?.trim() ?? "";
  const { data: cafes } = await listCafes();

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
        <div>
          <h2 className="text-2xl font-semibold">➕ Добавить позицию в меню</h2>
          <p className="mt-1 text-sm text-zinc-600">
            Создайте новую позицию меню для выбранной кофейни
          </p>
        </div>
      </div>

      {/* Form */}
      <form action={createMenuItem} className="space-y-6">
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
                defaultValue={preselectedCafeId}
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
                Выберите кофейню, в меню которой добавляется позиция
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
                placeholder="Капучино большой"
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
              <p className="mt-1 text-xs text-zinc-500">
                Название позиции, как оно будет отображаться в меню
              </p>
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
                placeholder="Классический капучино с молоком и эспрессо"
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
              <p className="mt-1 text-xs text-zinc-500">
                Краткое описание позиции (необязательно)
              </p>
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
                defaultValue="150"
                placeholder="150"
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
              <p className="mt-1 text-xs text-zinc-500">
                Цена в кредитах (1 кредит = 1 рубль)
              </p>
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
                defaultValue="120"
                placeholder="120"
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
              <p className="mt-1 text-xs text-zinc-500">
                Примерное время приготовления
              </p>
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
                defaultValue="0"
                placeholder="0"
                className="w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500"
              />
              <p className="mt-1 text-xs text-zinc-500">
                Позиции с меньшим числом отображаются первыми
              </p>
            </label>

            {/* Доступность */}
            <label className="flex items-start gap-3 rounded-lg border border-zinc-200 p-4">
              <input
                type="checkbox"
                name="is_available"
                defaultChecked
                className="mt-0.5"
              />
              <div>
                <div className="text-sm font-medium text-zinc-900">
                  Доступно для заказа
                </div>
                <div className="text-xs text-zinc-500">
                  Позиция будет отображаться в меню
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
            ✓ Создать позицию
          </button>
        </div>
      </form>
    </section>
  );
}
