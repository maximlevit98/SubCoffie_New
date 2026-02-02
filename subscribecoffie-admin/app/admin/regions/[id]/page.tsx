import Link from "next/link";

import { getRegionById, getCafesInRegion } from "../../../../lib/supabase/queries/regions";
import { listCafes } from "../../../../lib/supabase/queries/cafes";
import { getUserRole } from "../../../../lib/supabase/roles";
import { updateRegion, assignCafeToRegion, removeCafeFromRegion } from "../actions";

type RegionDetailPageProps = {
  params: Promise<{
    id: string;
  }>;
};

export default async function RegionDetailPage({ params }: RegionDetailPageProps) {
  const resolvedParams = await params;
  const regionId = resolvedParams.id;

  const [
    { data: region, error: regionError },
    { data: cafesInRegion, error: cafesError },
    { data: allCafes },
    { role },
  ] = await Promise.all([
    getRegionById(regionId),
    getCafesInRegion(regionId),
    listCafes(),
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

  if (regionError || !region) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Region Not Found</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {regionError || "Region not found"}
        </p>
        <Link
          href="/admin/regions"
          className="inline-flex items-center rounded border border-zinc-300 px-3 py-2 text-sm hover:bg-zinc-50"
        >
          Back to Regions
        </Link>
      </section>
    );
  }

  // Filter cafes that are NOT in this region
  const cafesInRegionIds = new Set(cafesInRegion?.map((c) => c.cafe_id) ?? []);
  const availableCafes = (allCafes ?? []).filter(
    (cafe) => !cafesInRegionIds.has(cafe.id)
  );

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <Link
            href="/admin/regions"
            className="text-sm text-zinc-500 hover:text-zinc-700"
          >
            ← Back to Regions
          </Link>
          <h2 className="text-2xl font-semibold mt-1">{region.region_name}</h2>
        </div>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>

      {/* Region Details Form */}
      <div className="rounded border border-zinc-200 bg-white p-4">
        <h3 className="text-sm font-semibold text-zinc-700">Region Details</h3>
        <form action={updateRegion} className="mt-3 grid gap-3 md:grid-cols-2">
          <input type="hidden" name="region_id" value={regionId} />

          <label className="grid gap-1 text-xs text-zinc-600">
            Name
            <input
              type="text"
              name="name"
              defaultValue={region.region_name}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            City
            <input
              type="text"
              name="city"
              defaultValue={region.city}
              disabled
              className="rounded border border-zinc-300 bg-zinc-50 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Country
            <input
              type="text"
              name="country"
              defaultValue={region.country}
              disabled
              className="rounded border border-zinc-300 bg-zinc-50 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Timezone
            <input
              type="text"
              name="timezone"
              defaultValue={region.timezone}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Latitude
            <input
              type="number"
              name="latitude"
              step="0.0001"
              defaultValue={region.latitude ?? ""}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Longitude
            <input
              type="number"
              name="longitude"
              step="0.0001"
              defaultValue={region.longitude ?? ""}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="flex items-center gap-2 text-xs text-zinc-600">
            <input
              type="checkbox"
              name="is_active"
              value="true"
              defaultChecked={region.is_active}
            />
            Active
          </label>

          <div className="flex items-end md:col-span-2">
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              Update Region
            </button>
          </div>
        </form>
      </div>

      {/* Assign Cafe to Region */}
      {availableCafes.length > 0 && (
        <div className="rounded border border-zinc-200 bg-white p-4">
          <h3 className="text-sm font-semibold text-zinc-700">Assign Cafe to Region</h3>
          <form action={assignCafeToRegion} className="mt-3 flex gap-3">
            <input type="hidden" name="region_id" value={regionId} />
            <select
              name="cafe_id"
              required
              className="flex-1 rounded border border-zinc-300 px-3 py-2 text-sm"
            >
              <option value="">Select a cafe...</option>
              {availableCafes.map((cafe) => (
                <option key={cafe.id} value={cafe.id}>
                  {cafe.name} - {cafe.address}
                </option>
              ))}
            </select>
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              Assign
            </button>
          </form>
        </div>
      )}

      {/* Cafes in Region Table */}
      <div className="rounded border border-zinc-200 bg-white">
        <div className="border-b border-zinc-200 p-4">
          <h3 className="text-sm font-semibold text-zinc-700">
            Cafes in Region ({cafesInRegion?.length ?? 0})
          </h3>
        </div>
        
        {cafesError ? (
          <div className="p-4">
            <p className="text-sm text-red-600">Failed to load cafes: {cafesError}</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
                <tr>
                  <th className="px-4 py-3 font-medium">Name</th>
                  <th className="px-4 py-3 font-medium">Address</th>
                  <th className="px-4 py-3 font-medium">Mode</th>
                  <th className="px-4 py-3 font-medium">Assigned</th>
                  <th className="px-4 py-3 font-medium">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {(cafesInRegion ?? []).map((cafe) => (
                  <tr key={cafe.cafe_id} className="text-zinc-700">
                    <td className="px-4 py-3 font-medium text-zinc-900">
                      {cafe.cafe_name}
                    </td>
                    <td className="px-4 py-3">{cafe.cafe_address}</td>
                    <td className="px-4 py-3">{cafe.cafe_mode}</td>
                    <td className="px-4 py-3 text-xs">
                      {new Date(cafe.assigned_at).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3">
                      <form action={removeCafeFromRegion}>
                        <input type="hidden" name="cafe_id" value={cafe.cafe_id} />
                        <input type="hidden" name="region_id" value={regionId} />
                        <button
                          type="submit"
                          className="rounded border border-red-300 px-3 py-1 text-xs font-medium text-red-600 hover:bg-red-50"
                        >
                          Remove
                        </button>
                      </form>
                    </td>
                  </tr>
                ))}
                {cafesInRegion && cafesInRegion.length === 0 && (
                  <tr>
                    <td
                      className="px-4 py-6 text-sm text-zinc-500"
                      colSpan={5}
                    >
                      No cafes assigned to this region yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </section>
  );
}
