import Link from "next/link";

import { listCafes } from "../../../lib/supabase/queries/cafes";
import { createCafe, updateCafeMode } from "./actions";

const MODE_OPTIONS = ["open", "busy", "paused", "closed"] as const;

type CafesPageProps = {
  searchParams?: Promise<{
    q?: string;
  }>;
};

export default async function CafesPage({ searchParams }: CafesPageProps) {
  const resolvedParams = await searchParams;
  const query = resolvedParams?.q?.trim() ?? "";
  const { data, error } = await listCafes(query);
  const retryHref = query
    ? `/admin/cafes?q=${encodeURIComponent(query)}`
    : "/admin/cafes";

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Cafes</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить список кофеен: {error}
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
        <h2 className="text-2xl font-semibold">Cafes</h2>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>
      <div className="rounded border border-zinc-200 bg-white p-4">
        <h3 className="text-sm font-semibold text-zinc-700">Add cafe</h3>
        <form action={createCafe} className="mt-3 grid gap-3 md:grid-cols-2">
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
            Address
            <input
              type="text"
              name="address"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>
          <label className="grid gap-1 text-xs text-zinc-600">
            Mode
            <select
              name="mode"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              defaultValue="open"
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
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>
          <label className="flex items-center gap-2 text-xs text-zinc-600">
            <input type="checkbox" name="supports_citypass" />
            Supports citypass
          </label>
          <label className="grid gap-1 text-xs text-zinc-600">
            Distance (km)
            <input
              type="number"
              name="distance_km"
              step="0.1"
              min="0"
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
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>
          <div className="flex items-end md:col-span-2">
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
            >
              Add cafe
            </button>
          </div>
        </form>
      </div>
      <form action="/admin/cafes" method="get" className="flex items-center gap-3">
        <input
          type="text"
          name="q"
          placeholder="Search by name"
          defaultValue={query}
          className="w-full max-w-sm rounded border border-zinc-300 px-3 py-2 text-sm"
        />
        <button
          type="submit"
          className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white"
        >
          Search
        </button>
      </form>
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Address</th>
              <th className="px-4 py-3 font-medium">Mode</th>
              <th className="px-4 py-3 font-medium">ETA (min)</th>
              <th className="px-4 py-3 font-medium">Citypass</th>
              <th className="px-4 py-3 font-medium">Distance (km)</th>
              <th className="px-4 py-3 font-medium">Rating</th>
              <th className="px-4 py-3 font-medium">Avg check</th>
              <th className="px-4 py-3 font-medium">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {(data ?? []).map((cafe) => (
              <tr key={cafe.id} className="text-zinc-700">
                <td className="px-4 py-3 font-medium text-zinc-900">
                  {cafe.name ?? "—"}
                </td>
                <td className="px-4 py-3">{cafe.address ?? "—"}</td>
                <td className="px-4 py-3">
                  <form
                    action={updateCafeMode}
                    className="flex items-center gap-2"
                  >
                    <input type="hidden" name="id" value={cafe.id} />
                    <select
                      name="mode"
                      defaultValue={cafe.mode ?? "open"}
                      className="rounded border border-zinc-300 px-2 py-1 text-xs"
                    >
                      {MODE_OPTIONS.map((mode) => (
                        <option key={mode} value={mode}>
                          {mode}
                        </option>
                      ))}
                    </select>
                    <button
                      type="submit"
                      className="rounded border border-zinc-300 px-2 py-1 text-xs hover:bg-zinc-50"
                    >
                      Save
                    </button>
                  </form>
                </td>
                <td className="px-4 py-3">
                  {cafe.eta_minutes ?? "—"}
                </td>
                <td className="px-4 py-3">
                  {cafe.supports_citypass === null ||
                  cafe.supports_citypass === undefined
                    ? "—"
                    : cafe.supports_citypass
                      ? "Yes"
                      : "No"}
                </td>
                <td className="px-4 py-3">{cafe.distance_km ?? "—"}</td>
                <td className="px-4 py-3">{cafe.rating ?? "—"}</td>
                <td className="px-4 py-3">
                  {cafe.avg_check_credits ?? "—"}
                </td>
                <td className="px-4 py-3">
                  <Link
                    href={`/admin/cafes/${cafe.id}`}
                    className="rounded border border-zinc-300 px-3 py-1 text-xs font-medium hover:bg-zinc-50"
                  >
                    Open
                  </Link>
                </td>
              </tr>
            ))}
            {data && data.length === 0 && (
              <tr>
                <td className="px-4 py-6 text-sm text-zinc-500" colSpan={9}>
                  No cafes found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
