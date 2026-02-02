import Link from "next/link";
import { redirect } from "next/navigation";

import { createAdminClient } from "../../../../lib/supabase/admin";
import { getUserRole } from "../../../../lib/supabase/roles";
import { deleteMenuItem, updateMenuItem } from "../actions";

const CATEGORY_OPTIONS = ["drinks", "food", "syrups", "merch"] as const;

type MenuItemPageProps = {
  params: {
    id: string;
  };
};

export default async function MenuItemPage({ params }: MenuItemPageProps) {
  const { role } = await getUserRole();

  if (role !== "admin") {
    redirect("/admin/menu-items");
  }

  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("menu_items")
    .select("*")
    .eq("id", params.id)
    .maybeSingle();

  if (error || !data) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Menu item</h2>
          <Link href="/admin/menu-items" className="text-sm text-zinc-600">
            Back to menu items
          </Link>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить позицию: {error?.message ?? "Not found"}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Menu item: {data.name}</h2>
        <Link href="/admin/menu-items" className="text-sm text-zinc-600">
          Back to menu items
        </Link>
      </div>

      <form action={updateMenuItem} className="grid gap-3 md:grid-cols-2">
        <input type="hidden" name="id" value={data.id} />
        <label className="grid gap-1 text-xs text-zinc-600">
          Cafe ID
          <input
            type="text"
            name="cafe_id"
            defaultValue={data.cafe_id ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <label className="grid gap-1 text-xs text-zinc-600">
          Category
          <select
            name="category"
            defaultValue={data.category ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          >
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
            defaultValue={data.name ?? ""}
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
            defaultValue={data.price_credits ?? ""}
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
            defaultValue={data.sort_order ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <label className="flex items-center gap-2 text-xs text-zinc-600">
          <input
            type="checkbox"
            name="is_available"
            defaultChecked={data.is_available ?? true}
          />
          Available
        </label>
        <label className="grid gap-1 text-xs text-zinc-600 md:col-span-2">
          Description
          <textarea
            name="description"
            rows={2}
            defaultValue={data.description ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <div className="flex items-end md:col-span-2">
          <button
            type="submit"
            className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
          >
            Save changes
          </button>
        </div>
      </form>

      <form
        action={deleteMenuItem}
        className="rounded border border-red-200 bg-red-50 p-4"
      >
        <input type="hidden" name="id" value={data.id} />
        <div className="flex flex-wrap items-center gap-3">
          <label className="flex items-center gap-2 text-xs text-red-700">
            <input type="checkbox" name="confirm" required />
            Confirm delete
          </label>
          <button
            type="submit"
            className="rounded bg-red-600 px-4 py-2 text-sm font-medium text-white"
          >
            Delete item
          </button>
        </div>
      </form>
    </section>
  );
}
