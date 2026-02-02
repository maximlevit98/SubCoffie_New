import Link from "next/link";

import { getAllFranchisePartners } from "../../../lib/supabase/queries/franchise";
import { getUserRole } from "../../../lib/supabase/roles";
import { createFranchisePartner } from "./actions";

type FranchisePageProps = {
  searchParams?: Promise<{
    status?: string;
  }>;
};

export default async function FranchisePage({ searchParams }: FranchisePageProps) {
  const resolvedParams = await searchParams;
  const statusFilter = resolvedParams?.status || null;
  
  const [{ data, error }, { role }] = await Promise.all([
    getAllFranchisePartners(statusFilter),
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
          <h2 className="text-2xl font-semibold">Franchise Partners</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Failed to load franchise partners: {error}
        </p>
        <Link
          href="/admin/franchise"
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
        <h2 className="text-2xl font-semibold">Franchise Partners</h2>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>

      {/* Create Franchise Partner Form */}
      <div className="rounded border border-zinc-200 bg-white p-4">
        <h3 className="text-sm font-semibold text-zinc-700">Add Franchise Partner</h3>
        <form action={createFranchisePartner} className="mt-3 grid gap-3 md:grid-cols-2">
          <label className="grid gap-1 text-xs text-zinc-600">
            User ID *
            <input
              type="text"
              name="user_id"
              required
              placeholder="UUID of the user"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Company Name *
            <input
              type="text"
              name="company_name"
              required
              placeholder="e.g., Coffee Chain LLC"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Contact Person *
            <input
              type="text"
              name="contact_person"
              required
              placeholder="John Doe"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Email *
            <input
              type="email"
              name="email"
              required
              placeholder="contact@example.com"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Phone *
            <input
              type="tel"
              name="phone"
              required
              placeholder="+7 (999) 123-45-67"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Tax ID
            <input
              type="text"
              name="tax_id"
              placeholder="123456789"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Commission Rate (%)
            <input
              type="number"
              name="commission_rate"
              step="0.01"
              min="0"
              max="100"
              defaultValue="10.00"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <div className="flex items-end md:col-span-2">
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              Add Franchise Partner
            </button>
          </div>
        </form>
      </div>

      {/* Status Filter */}
      <div className="flex gap-2">
        <Link
          href="/admin/franchise"
          className={`rounded border px-3 py-2 text-xs ${
            !statusFilter
              ? "border-zinc-900 bg-zinc-900 text-white"
              : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
          }`}
        >
          All
        </Link>
        <Link
          href="/admin/franchise?status=active"
          className={`rounded border px-3 py-2 text-xs ${
            statusFilter === "active"
              ? "border-emerald-600 bg-emerald-600 text-white"
              : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
          }`}
        >
          Active
        </Link>
        <Link
          href="/admin/franchise?status=suspended"
          className={`rounded border px-3 py-2 text-xs ${
            statusFilter === "suspended"
              ? "border-orange-600 bg-orange-600 text-white"
              : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
          }`}
        >
          Suspended
        </Link>
        <Link
          href="/admin/franchise?status=terminated"
          className={`rounded border px-3 py-2 text-xs ${
            statusFilter === "terminated"
              ? "border-red-600 bg-red-600 text-white"
              : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
          }`}
        >
          Terminated
        </Link>
      </div>

      {/* Franchise Partners Table */}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Company</th>
              <th className="px-4 py-3 font-medium">Contact</th>
              <th className="px-4 py-3 font-medium">Email</th>
              <th className="px-4 py-3 font-medium">Phone</th>
              <th className="px-4 py-3 font-medium">Commission</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Regions</th>
              <th className="px-4 py-3 font-medium">Cafes</th>
              <th className="px-4 py-3 font-medium">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {(data ?? []).map((franchise) => (
              <tr key={franchise.franchise_id} className="text-zinc-700">
                <td className="px-4 py-3 font-medium text-zinc-900">
                  {franchise.company_name}
                </td>
                <td className="px-4 py-3">{franchise.contact_person}</td>
                <td className="px-4 py-3 text-xs">{franchise.email}</td>
                <td className="px-4 py-3 text-xs">{franchise.phone}</td>
                <td className="px-4 py-3">{franchise.commission_rate}%</td>
                <td className="px-4 py-3">
                  <span
                    className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                      franchise.status === "active"
                        ? "bg-emerald-50 text-emerald-700"
                        : franchise.status === "suspended"
                          ? "bg-orange-50 text-orange-700"
                          : "bg-red-50 text-red-700"
                    }`}
                  >
                    {franchise.status}
                  </span>
                </td>
                <td className="px-4 py-3">{franchise.region_count ?? 0}</td>
                <td className="px-4 py-3">{franchise.cafe_count}</td>
                <td className="px-4 py-3">
                  <Link
                    href={`/admin/franchise/${franchise.franchise_id}`}
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
                  colSpan={9}
                >
                  No franchise partners found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
