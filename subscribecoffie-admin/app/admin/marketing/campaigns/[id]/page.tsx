import Link from "next/link";
import { getCampaignById } from "@/lib/supabase/queries/marketing";
import { deleteCampaign, updateCampaign } from "../../actions";

export default async function CampaignDetailPage({ params }: { params: { id: string } }) {
  const { data: campaign, error } = await getCampaignById(params.id);

  if (error || !campaign) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Campaign Not Found</h2>
        <p className="text-zinc-600">{error || "Could not find the requested campaign."}</p>
        <Link
          href="/admin/marketing/campaigns"
          className="text-emerald-600 hover:underline"
        >
          ← Back to Campaigns
        </Link>
      </section>
    );
  }

  const ctr = campaign.impressions_count > 0
    ? (campaign.clicks_count / campaign.impressions_count * 100).toFixed(2)
    : "0.00";
  
  const conversionRate = campaign.clicks_count > 0
    ? (campaign.conversions_count / campaign.clicks_count * 100).toFixed(2)
    : "0.00";

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">{campaign.name}</h2>
          <p className="text-sm text-zinc-600 mt-1">{campaign.description || "No description"}</p>
        </div>
        <Link
          href="/admin/marketing/campaigns"
          className="text-sm text-zinc-600 hover:text-zinc-900"
        >
          ← Back to Campaigns
        </Link>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Impressions</div>
          <div className="text-2xl font-bold text-zinc-900">
            {campaign.impressions_count || 0}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Clicks</div>
          <div className="text-2xl font-bold text-zinc-900">
            {campaign.clicks_count || 0}
          </div>
          <div className="text-xs text-zinc-500 mt-1">CTR: {ctr}%</div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Conversions</div>
          <div className="text-2xl font-bold text-emerald-600">
            {campaign.conversions_count || 0}
          </div>
          <div className="text-xs text-zinc-500 mt-1">Rate: {conversionRate}%</div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Status</div>
          <div className="mt-2">
            <span
              className={`inline-block rounded px-3 py-1 text-sm font-medium ${
                campaign.status === "active"
                  ? "bg-emerald-100 text-emerald-700"
                  : campaign.status === "completed"
                  ? "bg-zinc-100 text-zinc-600"
                  : campaign.status === "scheduled"
                  ? "bg-blue-100 text-blue-700"
                  : "bg-zinc-100 text-zinc-600"
              }`}
            >
              {campaign.status}
            </span>
          </div>
        </div>
      </div>

      {/* Details Card */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
        <h3 className="text-lg font-semibold">Campaign Details</h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-zinc-600">Campaign Type:</span>
            <div className="font-medium mt-1">
              <span className="inline-block rounded px-2 py-1 text-xs bg-blue-100 text-blue-700">
                {campaign.campaign_type}
              </span>
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Associated Promo Code:</span>
            <div className="font-medium mt-1">
              {campaign.promo_codes ? (
                <Link
                  href={`/admin/marketing/promo-codes/${campaign.promo_code_id}`}
                  className="font-mono text-emerald-600 hover:underline"
                >
                  {campaign.promo_codes.code}
                </Link>
              ) : (
                <span className="text-zinc-500">None</span>
              )}
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Start Date:</span>
            <div className="font-medium mt-1">
              {campaign.start_date
                ? new Date(campaign.start_date).toLocaleDateString()
                : "Not set"}
            </div>
          </div>
          <div>
            <span className="text-zinc-600">End Date:</span>
            <div className="font-medium mt-1">
              {campaign.end_date
                ? new Date(campaign.end_date).toLocaleDateString()
                : "Ongoing"}
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Created:</span>
            <div className="font-medium mt-1">
              {new Date(campaign.created_at).toLocaleDateString()}
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Last Updated:</span>
            <div className="font-medium mt-1">
              {new Date(campaign.updated_at).toLocaleDateString()}
            </div>
          </div>
        </div>
      </div>

      {/* Promo Code Stats */}
      {campaign.promo_codes && (
        <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
          <h3 className="text-lg font-semibold">Promo Code Performance</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
            <div>
              <span className="text-zinc-600">Code:</span>
              <div className="font-mono font-semibold mt-1">{campaign.promo_codes.code}</div>
            </div>
            <div>
              <span className="text-zinc-600">Discount:</span>
              <div className="font-medium mt-1">
                {campaign.promo_codes.discount_type === "percentage"
                  ? `${campaign.promo_codes.discount_value}%`
                  : `${campaign.promo_codes.discount_value} ₽`}
              </div>
            </div>
            <div>
              <span className="text-zinc-600">Total Uses:</span>
              <div className="font-medium mt-1">{campaign.promo_codes.uses_count || 0}</div>
            </div>
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-3">
        <form action={deleteCampaign} onSubmit={(e) => {
          if (!confirm("Are you sure you want to delete this campaign? This action cannot be undone.")) {
            e.preventDefault();
          }
        }}>
          <input type="hidden" name="id" value={campaign.id} />
          <input type="hidden" name="confirm" value="yes" />
          <button
            type="submit"
            className="rounded-lg border border-red-300 px-4 py-2 text-sm font-medium text-red-600 hover:bg-red-50"
          >
            Delete Campaign
          </button>
        </form>
      </div>

      <div className="rounded border border-blue-200 bg-blue-50 p-4">
        <p className="text-sm text-blue-800">
          <strong>Track Performance:</strong> Monitor impressions, clicks, and conversions to measure
          the success of your marketing campaigns. Use this data to optimize future campaigns.
        </p>
      </div>
    </section>
  );
}
