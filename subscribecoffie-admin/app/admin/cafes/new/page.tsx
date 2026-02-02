import Link from "next/link";
import { createCafe } from "../actions";

const MODE_OPTIONS = [
  { value: "open", label: "🟢 Открыто" },
  { value: "busy", label: "🟡 Много заказов" },
  { value: "paused", label: "🟠 Приостановлено" },
  { value: "closed", label: "🔴 Закрыто" },
] as const;

export default function NewCafePage() {
  return (
    <section className="mx-auto max-w-4xl space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Добавить новую кофейню</h2>
        <Link
          href="/admin/cafes"
          className="rounded border border-zinc-300 px-4 py-2 text-sm hover:bg-zinc-50"
        >
          ← Назад
        </Link>
      </div>

      <form action={createCafe} className="space-y-6">
        {/* Основная информация */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold text-zinc-900">
            Основная информация
          </h3>
          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Название кофейни <span className="text-red-500">*</span>
              </span>
              <input
                type="text"
                name="name"
                required
                placeholder="Например: Coffee House на Пушкина"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Адрес <span className="text-red-500">*</span>
              </span>
              <input
                type="text"
                name="address"
                required
                placeholder="Например: ул. Пушкина, д. 10"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Телефон
              </span>
              <input
                type="tel"
                name="phone"
                placeholder="+7 (999) 123-45-67"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Email
              </span>
              <input
                type="email"
                name="email"
                placeholder="cafe@example.com"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5 md:col-span-2">
              <span className="text-sm font-medium text-zinc-700">
                Описание
              </span>
              <textarea
                name="description"
                rows={3}
                placeholder="Краткое описание кофейни..."
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>
          </div>
        </div>

        {/* Рабочие параметры */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold text-zinc-900">
            Рабочие параметры
          </h3>
          <div className="grid gap-4 md:grid-cols-3">
            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Статус <span className="text-red-500">*</span>
              </span>
              <select
                name="mode"
                defaultValue="open"
                required
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              >
                {MODE_OPTIONS.map((mode) => (
                  <option key={mode.value} value={mode.value}>
                    {mode.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Время приготовления (мин)
              </span>
              <input
                type="number"
                name="eta_minutes"
                step="1"
                min="0"
                max="120"
                defaultValue="15"
                placeholder="15"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Макс. активных заказов
              </span>
              <input
                type="number"
                name="max_active_orders"
                step="1"
                min="1"
                max="100"
                defaultValue="10"
                placeholder="10"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="flex items-center gap-2 rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3">
              <input
                type="checkbox"
                name="supports_citypass"
                defaultChecked
                className="h-4 w-4 rounded border-zinc-300 text-blue-600 focus:ring-2 focus:ring-blue-500"
              />
              <span className="text-sm font-medium text-zinc-700">
                Поддержка CityPass
              </span>
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Расстояние от центра (км)
              </span>
              <input
                type="number"
                name="distance_km"
                step="0.1"
                min="0"
                max="50"
                placeholder="2.5"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Рейтинг (0-5)
              </span>
              <input
                type="number"
                name="rating"
                step="0.1"
                min="0"
                max="5"
                placeholder="4.5"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Средний чек (₽)
              </span>
              <input
                type="number"
                name="avg_check_credits"
                step="1"
                min="0"
                placeholder="350"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Текущих заказов
              </span>
              <input
                type="number"
                name="active_orders"
                step="1"
                min="0"
                defaultValue="0"
                placeholder="0"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>
          </div>
        </div>

        {/* Координаты (для будущей карты) */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold text-zinc-900">
            Координаты <span className="text-xs text-zinc-500">(опционально)</span>
          </h3>
          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Широта (latitude)
              </span>
              <input
                type="number"
                name="latitude"
                step="0.000001"
                min="-90"
                max="90"
                placeholder="55.751244"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
              <span className="text-xs text-zinc-500">
                Например: 55.751244 для Москвы
              </span>
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Долгота (longitude)
              </span>
              <input
                type="number"
                name="longitude"
                step="0.000001"
                min="-180"
                max="180"
                placeholder="37.618423"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
              <span className="text-xs text-zinc-500">
                Например: 37.618423 для Москвы
              </span>
            </label>
          </div>
        </div>

        {/* Часы работы */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 className="mb-4 text-lg font-semibold text-zinc-900">
            Часы работы <span className="text-xs text-zinc-500">(опционально)</span>
          </h3>
          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Открытие
              </span>
              <input
                type="time"
                name="opening_time"
                defaultValue="08:00"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>

            <label className="grid gap-1.5">
              <span className="text-sm font-medium text-zinc-700">
                Закрытие
              </span>
              <input
                type="time"
                name="closing_time"
                defaultValue="22:00"
                className="rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </label>
          </div>
        </div>

        {/* Кнопки действий */}
        <div className="flex items-center justify-end gap-3">
          <Link
            href="/admin/cafes"
            className="rounded-lg border border-zinc-300 px-6 py-2.5 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
          >
            Отмена
          </Link>
          <button
            type="submit"
            className="rounded-lg bg-blue-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            Создать кофейню
          </button>
        </div>
      </form>
    </section>
  );
}
