import Link from "next/link";
import { listPromoCodes } from "@/lib/supabase/queries/marketing";
import { createCampaign } from "../../actions";

export default async function NewCampaignPage() {
  const { data: promoCodes } = await listPromoCodes(true);

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Create Campaign</h2>
          <p className="text-sm text-zinc-600 mt-1">
            Set up a new marketing campaign
          </p>
        </div>
        <Link
          href="/admin/marketing/campaigns"
          className="text-sm text-zinc-600 hover:text-zinc-900"
        >
          ← Back to Campaigns
        </Link>
      </div>

      <form action={createCampaign} className="space-y-6">
        <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
          <h3 className="text-lg font-semibold">Basic Information</h3>
          
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-zinc-700">
              Campaign Name <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              id="name"
              name="name"
              required
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="Summer 2026 Promotion"
            />
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium text-zinc-700">
              Description
            </label>
            <textarea
              id="description"
              name="description"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              rows={3}
              placeholder="Promote our summer promo code with 20% discount..."
            />
          </div>

          <div>
            <label htmlFor="campaign_type" className="block text-sm font-medium text-zinc-700">
              Campaign Type <span className="text-red-500">*</span>
            </label>
            <select
              id="campaign_type"
              name="campaign_type"
              required
              defaultValue="promo"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            >
              <option value="promo">Promo Code Campaign</option>
              <option value="push_notification">Push Notification</option>
              <option value="email">Email Campaign</option>
              <option value="banner">Banner/In-App</option>
              <option value="loyalty">Loyalty Program</option>
            </select>
          </div>

          <div>
            <label htmlFor="promo_code_id" className="block text-sm font-medium text-zinc-700">
              Associated Promo Code
            </label>
            <select
              id="promo_code_id"
              name="promo_code_id"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            >
              <option value="">None</option>
              {promoCodes?.map((promo) => (
                <option key={promo.id} value={promo.id}>
                  {promo.code} - {promo.description || "No description"}
                </option>
              ))}
            </select>
            <p className="mt-1 text-xs text-zinc-500">
              Optional: Link a promo code to track conversions
            </p>
          </div>

          <div>
            <label htmlFor="status" className="block text-sm font-medium text-zinc-700">
              Status
            </label>
            <select
              id="status"
              name="status"
              defaultValue="draft"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            >
              <option value="draft">Draft</option>
              <option value="scheduled">Scheduled</option>
              <option value="active">Active</option>
              <option value="paused">Paused</option>
            </select>
          </div>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
          <h3 className="text-lg font-semibold">Schedule</h3>
          
          <div>
            <label htmlFor="start_date" className="block text-sm font-medium text-zinc-700">
              Start Date
            </label>
            <input
              type="date"
              id="start_date"
              name="start_date"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </div>

          <div>
            <label htmlFor="end_date" className="block text-sm font-medium text-zinc-700">
              End Date
            </label>
            <input
              type="date"
              id="end_date"
              name="end_date"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Leave empty for ongoing campaigns
            </p>
          </div>
        </div>

        <div className="flex justify-end gap-3">
          <Link
            href="/admin/marketing/campaigns"
            className="rounded-lg border border-zinc-300 px-6 py-2 text-sm font-medium hover:bg-zinc-50"
          >
            Cancel
          </Link>
          <button
            type="submit"
            className="rounded-lg bg-emerald-600 px-6 py-2 text-sm font-medium text-white hover:bg-emerald-700"
          >
            Create Campaign
          </button>
        </div>
      </form>
    </section>
  );
}
