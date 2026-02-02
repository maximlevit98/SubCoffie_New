import Link from "next/link";

import { getAllRegions } from "../../../lib/supabase/queries/regions";
import { getUserRole } from "../../../lib/supabase/roles";
import { createRegion } from "./actions";

export default async function RegionsPage() {
  const [{ data, error }, { role }] = await Promise.all([
    getAllRegions(true),
    getUserRole(),
  ]);
  const isAdmin = role === "admin";

  if (!isAdmin) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Access Denied</h2>
        <p className="text-sm text-red-600">
          Only administrators can access this page.
        </p>
      </section>
    );
  }

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Regions</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Failed to load regions: {error}
        </p>
        <Link
          href="/admin/regions"
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
        <h2 className="text-2xl font-semibold">Regions</h2>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>

      {/* Create Region Form */}
      <div className="rounded border border-zinc-200 bg-white p-4">
        <h3 className="text-sm font-semibold text-zinc-700">Add Region</h3>
        <form action={createRegion} className="mt-3 grid gap-3 md:grid-cols-2">
          <label className="grid gap-1 text-xs text-zinc-600">
            Name *
            <input
              type="text"
              name="name"
              required
              placeholder="e.g., Moscow Central"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            City *
            <input
              type="text"
              name="city"
              required
              placeholder="e.g., Moscow"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Country
            <input
              type="text"
              name="country"
              defaultValue="Russia"
              placeholder="Russia"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Timezone
            <input
              type="text"
              name="timezone"
              defaultValue="Europe/Moscow"
              placeholder="Europe/Moscow"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Latitude
            <input
              type="number"
              name="latitude"
              step="0.0001"
              placeholder="55.7558"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Longitude
            <input
              type="number"
              name="longitude"
              step="0.0001"
              placeholder="37.6173"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <div className="flex items-end md:col-span-2">
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              Add Region
            </button>
          </div>
        </form>
      </div>

      {/* Regions Table */}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">City</th>
              <th className="px-4 py-3 font-medium">Country</th>
              <th className="px-4 py-3 font-medium">Timezone</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Cafes</th>
              <th className="px-4 py-3 font-medium">Created</th>
              <th className="px-4 py-3 font-medium">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {(data ?? []).map((region) => (
              <tr key={region.region_id} className="text-zinc-700">
                <td className="px-4 py-3 font-medium text-zinc-900">
                  {region.region_name}
                </td>
                <td className="px-4 py-3">{region.city}</td>
                <td className="px-4 py-3">{region.country}</td>
                <td className="px-4 py-3 text-xs">{region.timezone}</td>
                <td className="px-4 py-3">
                  <span
                    className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                      region.is_active
                        ? "bg-emerald-50 text-emerald-700"
                        : "bg-red-50 text-red-700"
                    }`}
                  >
                    {region.is_active ? "Active" : "Inactive"}
                  </span>
                </td>
                <td className="px-4 py-3">{region.cafe_count}</td>
                <td className="px-4 py-3 text-xs">
                  {new Date(region.created_at).toLocaleDateString()}
                </td>
                <td className="px-4 py-3">
                  <Link
                    href={`/admin/regions/${region.region_id}`}
                    className="rounded border border-zinc-300 px-3 py-1 text-xs font-medium hover:bg-zinc-50"
                  >
                    Manage
                  </Link>
                </td>
              </tr>
            ))}
            {data && data.length === 0 && (
              <tr>
                <td
                  className="px-4 py-6 text-sm text-zinc-500"
                  colSpan={8}
                >
                  No regions found. Create one to get started.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
