import Link from "next/link";

import { createAdminClient } from "../../../../lib/supabase/admin";
import { deleteCafe, updateCafe } from "../actions";

const MODE_OPTIONS = ["open", "busy", "paused", "closed"] as const;

type CafeDetailsPageProps = {
  params: {
    id: string;
  };
};

export default async function CafeDetailsPage({ params }: CafeDetailsPageProps) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("cafes")
    .select("*")
    .eq("id", params.id)
    .maybeSingle();

  if (error || !data) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Cafe</h2>
          <Link href="/admin/cafes" className="text-sm text-zinc-600">
            Back to cafes
          </Link>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить кофейню: {error?.message ?? "Not found"}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Cafe: {data.name}</h2>
        <Link href="/admin/cafes" className="text-sm text-zinc-600">
          Back to cafes
        </Link>
      </div>
      <form action={updateCafe} className="grid gap-3 md:grid-cols-2">
        <input type="hidden" name="id" value={data.id} />
        <label className="grid gap-1 text-xs text-zinc-600">
          Name
          <input
            type="text"
            name="name"
            required
            defaultValue={data.name ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <label className="grid gap-1 text-xs text-zinc-600">
          Address
          <input
            type="text"
            name="address"
            defaultValue={data.address ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <label className="grid gap-1 text-xs text-zinc-600">
          Mode
          <select
            name="mode"
            defaultValue={data.mode ?? "open"}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          >
            {MODE_OPTIONS.map((mode) => (
              <option key={mode} value={mode}>
                {mode}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-xs text-zinc-600">
          ETA (minutes)
          <input
            type="number"
            name="eta_minutes"
            step="1"
            min="0"
            defaultValue={data.eta_minutes ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <label className="flex items-center gap-2 text-xs text-zinc-600">
          <input
            type="checkbox"
            name="supports_citypass"
            defaultChecked={Boolean(data.supports_citypass)}
          />
          Supports citypass
        </label>
        <label className="grid gap-1 text-xs text-zinc-600">
          Distance (km)
          <input
            type="number"
            name="distance_km"
            step="0.1"
            min="0"
            defaultValue={data.distance_km ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <label className="grid gap-1 text-xs text-zinc-600">
          Rating (0-5)
          <input
            type="number"
            name="rating"
            step="0.1"
            min="0"
            max="5"
            defaultValue={data.rating ?? ""}
            className="rounded border border-zinc-300 px-3 py-2 text-sm"
          />
        </label>
        <label className="grid gap-1 text-xs text-zinc-600">
          Avg check credits
          <input
            type="number"
            name="avg_check_credits"
            step="1"
            min="0"
            defaultValue={data.avg_check_credits ?? ""}
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
        action={deleteCafe}
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
            Delete cafe
          </button>
        </div>
      </form>
    </section>
  );
}
