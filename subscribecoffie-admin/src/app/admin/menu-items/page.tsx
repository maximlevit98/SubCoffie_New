import Link from "next/link";

import { listCafes } from "../../../lib/supabase/queries/cafes";
import { listMenuItems } from "../../../lib/supabase/queries/menu-items";
import { getUserRole } from "../../../lib/supabase/roles";
import { createMenuItem } from "./actions";
import MenuItemsTable from "./MenuItemsTable";

const CATEGORY_OPTIONS = ["drinks", "food", "syrups", "merch"] as const;

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
          <h2 className="text-2xl font-semibold">Menu Items</h2>
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

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Menu Items</h2>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>

      {isAdmin && (
        <div className="rounded border border-zinc-200 bg-white p-4">
          <h3 className="text-sm font-semibold text-zinc-700">Add menu item</h3>
          <form
            action={createMenuItem}
            className="mt-3 grid gap-3 md:grid-cols-2"
          >
            <label className="grid gap-1 text-xs text-zinc-600">
              Cafe
              <select
                name="cafe_id"
                required
                className="rounded border border-zinc-300 px-3 py-2 text-sm"
              >
                <option value="">Select cafe</option>
                {(cafes ?? []).map((cafe) => (
                  <option key={cafe.id} value={cafe.id}>
                    {cafe.name ?? cafe.id}
                  </option>
                ))}
              </select>
            </label>
            <label className="grid gap-1 text-xs text-zinc-600">
              Category
              <select
                name="category"
                required
                className="rounded border border-zinc-300 px-3 py-2 text-sm"
              >
                <option value="">Select category</option>
                {CATEGORY_OPTIONS.map((category) => (
                  <option key={category} value={category}>
                    {category}
                  </option>
                ))}
              </select>
            </label>
            <label className="grid gap-1 text-xs text-zinc-600">
              Name
              <input
                type="text"
                name="name"
                required
                className="rounded border border-zinc-300 px-3 py-2 text-sm"
              />
            </label>
            <label className="grid gap-1 text-xs text-zinc-600">
              Price (credits)
              <input
                type="number"
                name="price_credits"
                step="1"
                min="0"
                className="rounded border border-zinc-300 px-3 py-2 text-sm"
              />
            </label>
            <label className="grid gap-1 text-xs text-zinc-600">
              Sort order
              <input
                type="number"
                name="sort_order"
                step="1"
                min="0"
                className="rounded border border-zinc-300 px-3 py-2 text-sm"
              />
            </label>
            <label className="grid gap-1 text-xs text-zinc-600">
              Prep time (sec)
              <input
                type="number"
                name="prep_time_sec"
                step="1"
                min="0"
                className="rounded border border-zinc-300 px-3 py-2 text-sm"
              />
            </label>
            <label className="flex items-center gap-2 text-xs text-zinc-600">
              <input type="checkbox" name="is_available" defaultChecked />
              Available
            </label>
            <label className="grid gap-1 text-xs text-zinc-600 md:col-span-2">
              Description
              <textarea
                name="description"
                rows={2}
                className="rounded border border-zinc-300 px-3 py-2 text-sm"
              />
            </label>
            <div className="flex items-end md:col-span-2">
              <button
                type="submit"
                className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
              >
                Add item
              </button>
            </div>
          </form>
        </div>
      )}

      <form
        action="/admin/menu-items"
        method="get"
        className="flex items-center gap-3"
      >
        <input
          type="text"
          name="cafe_id"
          placeholder="Filter by cafe_id"
          defaultValue={cafeId}
          className="w-full max-w-sm rounded border border-zinc-300 px-3 py-2 text-sm"
        />
        <button
          type="submit"
          className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
        >
          Filter
        </button>
      </form>

      <MenuItemsTable items={items ?? []} canEdit={isAdmin} />
    </section>
  );
}
