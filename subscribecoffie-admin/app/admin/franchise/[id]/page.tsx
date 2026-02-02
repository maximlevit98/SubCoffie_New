import Link from "next/link";

import { getFranchisePartnerDetails } from "../../../../lib/supabase/queries/franchise";
import { getUserRole } from "../../../../lib/supabase/roles";
import { updateFranchisePartner } from "../actions";

type FranchiseDetailPageProps = {
  params: Promise<{
    id: string;
  }>;
};

const STATUS_OPTIONS = ["active", "suspended", "terminated"] as const;

export default async function FranchiseDetailPage({ params }: FranchiseDetailPageProps) {
  const resolvedParams = await params;
  const franchiseId = resolvedParams.id;

  const [
    { data: franchise, error: franchiseError },
    { role },
  ] = await Promise.all([
    getFranchisePartnerDetails(franchiseId),
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

  if (franchiseError || !franchise) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Franchise Partner Not Found</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {franchiseError || "Franchise partner not found"}
        </p>
        <Link
          href="/admin/franchise"
          className="inline-flex items-center rounded border border-zinc-300 px-3 py-2 text-sm hover:bg-zinc-50"
        >
          Back to Franchise Partners
        </Link>
      </section>
    );
  }

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <Link
            href="/admin/franchise"
            className="text-sm text-zinc-500 hover:text-zinc-700"
          >
            ← Back to Franchise Partners
          </Link>
          <h2 className="text-2xl font-semibold mt-1">{franchise.company_name}</h2>
        </div>
        <span className="text-sm text-emerald-600">Supabase: OK</span>
      </div>

      {/* Franchise Details Grid */}
      <div className="grid gap-4 md:grid-cols-3">
        <div className="rounded border border-zinc-200 bg-white p-4">
          <h3 className="text-xs font-medium text-zinc-500">Status</h3>
          <p className="mt-1">
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
          </p>
        </div>

        <div className="rounded border border-zinc-200 bg-white p-4">
          <h3 className="text-xs font-medium text-zinc-500">Commission Rate</h3>
          <p className="mt-1 text-xl font-semibold text-zinc-900">
            {franchise.commission_rate}%
          </p>
        </div>

        <div className="rounded border border-zinc-200 bg-white p-4">
          <h3 className="text-xs font-medium text-zinc-500">Regions</h3>
          <p className="mt-1 text-xl font-semibold text-zinc-900">
            {franchise.regions?.length ?? 0}
          </p>
        </div>
      </div>

      {/* Update Form */}
      <div className="rounded border border-zinc-200 bg-white p-4">
        <h3 className="text-sm font-semibold text-zinc-700">Franchise Details</h3>
        <form action={updateFranchisePartner} className="mt-3 grid gap-3 md:grid-cols-2">
          <input type="hidden" name="franchise_id" value={franchiseId} />

          <label className="grid gap-1 text-xs text-zinc-600">
            Company Name
            <input
              type="text"
              name="company_name"
              defaultValue={franchise.company_name}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Contact Person
            <input
              type="text"
              name="contact_person"
              defaultValue={franchise.contact_person}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Email
            <input
              type="email"
              name="email"
              defaultValue={franchise.email}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Phone
            <input
              type="tel"
              name="phone"
              defaultValue={franchise.phone}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Tax ID
            <input
              type="text"
              name="tax_id"
              defaultValue={franchise.tax_id ?? ""}
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
              defaultValue={franchise.commission_rate}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            Status
            <select
              name="status"
              defaultValue={franchise.status}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            >
              {STATUS_OPTIONS.map((status) => (
                <option key={status} value={status}>
                  {status}
                </option>
              ))}
            </select>
          </label>

          <label className="grid gap-1 text-xs text-zinc-600">
            User ID
            <input
              type="text"
              name="user_id"
              defaultValue={franchise.user_id}
              disabled
              className="rounded border border-zinc-300 bg-zinc-50 px-3 py-2 text-sm"
            />
          </label>

          <label className="grid gap-1 text-xs text-zinc-600 md:col-span-2">
            Notes
            <textarea
              name="notes"
              rows={3}
              defaultValue={franchise.notes ?? ""}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </label>

          <div className="flex items-end md:col-span-2">
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
            >
              Update Franchise Partner
            </button>
          </div>
        </form>
      </div>

      {/* Contract Information */}
      {(franchise.contract_number || franchise.contract_start_date || franchise.contract_end_date) && (
        <div className="rounded border border-zinc-200 bg-white p-4">
          <h3 className="text-sm font-semibold text-zinc-700">Contract Information</h3>
          <dl className="mt-3 grid gap-3 text-sm md:grid-cols-3">
            {franchise.contract_number && (
              <div>
                <dt className="text-xs font-medium text-zinc-500">Contract Number</dt>
                <dd className="mt-1 text-zinc-900">{franchise.contract_number}</dd>
              </div>
            )}
            {franchise.contract_start_date && (
              <div>
                <dt className="text-xs font-medium text-zinc-500">Start Date</dt>
                <dd className="mt-1 text-zinc-900">
                  {new Date(franchise.contract_start_date).toLocaleDateString()}
                </dd>
              </div>
            )}
            {franchise.contract_end_date && (
              <div>
                <dt className="text-xs font-medium text-zinc-500">End Date</dt>
                <dd className="mt-1 text-zinc-900">
                  {new Date(franchise.contract_end_date).toLocaleDateString()}
                </dd>
              </div>
            )}
          </dl>
        </div>
      )}

      {/* Metadata */}
      <div className="rounded border border-zinc-200 bg-white p-4">
        <h3 className="text-sm font-semibold text-zinc-700">Metadata</h3>
        <dl className="mt-3 grid gap-3 text-sm md:grid-cols-2">
          <div>
            <dt className="text-xs font-medium text-zinc-500">Created</dt>
            <dd className="mt-1 text-zinc-900">
              {new Date(franchise.created_at).toLocaleString()}
            </dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-zinc-500">Last Updated</dt>
            <dd className="mt-1 text-zinc-900">
              {new Date(franchise.updated_at).toLocaleString()}
            </dd>
          </div>
          {franchise.user_email && (
            <div>
              <dt className="text-xs font-medium text-zinc-500">User Email</dt>
              <dd className="mt-1 text-zinc-900">{franchise.user_email}</dd>
            </div>
          )}
        </dl>
      </div>
    </section>
  );
}
