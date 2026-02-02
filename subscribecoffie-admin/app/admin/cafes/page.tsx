import Link from "next/link";

import { listCafes } from "../../../lib/supabase/queries/cafes";
import { getUserRole } from "../../../lib/supabase/roles";
import { updateCafeMode } from "./actions";

const MODE_OPTIONS = ["open", "busy", "paused", "closed"] as const;

type CafesPageProps = {
  searchParams?: Promise<{
    q?: string;
  }>;
};

export default async function CafesPage({ searchParams }: CafesPageProps) {
  const resolvedParams = await searchParams;
  const query = resolvedParams?.q?.trim() ?? "";
  const [{ data, error }, { role }] = await Promise.all([
    listCafes(query),
    getUserRole(),
  ]);
  const isAdmin = role === "admin";
  const retryHref = query ? `/admin/cafes?q=${encodeURIComponent(query)}` : "/admin/cafes";

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
        <div className="flex items-center gap-3">
          {isAdmin && (
            <Link
              href="/admin/cafes/new"
              className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clipRule="evenodd" />
              </svg>
              Добавить кофейню
            </Link>
          )}
          <span className="text-sm text-emerald-600">Supabase: OK</span>
        </div>
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
              {isAdmin && <th className="px-4 py-3 font-medium">Actions</th>}
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
                  {isAdmin ? (
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
                  ) : (
                    cafe.mode ?? "—"
                  )}
                </td>
                <td className="px-4 py-3">
                  {cafe.eta_minutes ?? "—"}
                </td>
                <td className="px-4 py-3">
                  {cafe.supports_citypass === null || cafe.supports_citypass === undefined
                    ? "—"
                    : cafe.supports_citypass
                      ? "Yes"
                      : "No"}
                </td>
                <td className="px-4 py-3">
                  {cafe.distance_km ?? "—"}
                </td>
                <td className="px-4 py-3">{cafe.rating ?? "—"}</td>
                <td className="px-4 py-3">
                  {cafe.avg_check_credits ?? "—"}
                </td>
                {isAdmin && (
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <Link
                        href={`/admin/cafes/${cafe.id}`}
                        className="rounded border border-zinc-300 px-3 py-1 text-xs font-medium hover:bg-zinc-50"
                      >
                        Редактировать
                      </Link>
                      <Link
                        href={`/admin/menu-items?cafe_id=${cafe.id}`}
                        className="rounded border border-blue-300 bg-blue-50 px-3 py-1 text-xs font-medium text-blue-700 hover:bg-blue-100"
                      >
                        🍽️ Меню
                      </Link>
                    </div>
                  </td>
                )}
              </tr>
            ))}
            {data && data.length === 0 && (
              <tr>
                <td
                  className="px-4 py-6 text-sm text-zinc-500"
                  colSpan={isAdmin ? 9 : 8}
                >
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
