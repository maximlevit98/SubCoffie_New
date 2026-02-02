import Link from "next/link";
import { listCampaigns, getCampaignPerformance } from "@/lib/supabase/queries/marketing";

export default async function CampaignsPage() {
  const { data: campaigns, error } = await listCampaigns();
  const { data: performance } = await getCampaignPerformance();

  if (error) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Campaigns</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Failed to load campaigns: {error}
        </p>
      </section>
    );
  }

  const activeCampaigns = campaigns?.filter((c) => c.status === "active") || [];
  const totalImpressions = performance?.reduce((sum, p) => sum + (p.impressions_count || 0), 0) || 0;
  const totalClicks = performance?.reduce((sum, p) => sum + (p.clicks_count || 0), 0) || 0;
  const totalConversions = performance?.reduce((sum, p) => sum + (p.conversions_count || 0), 0) || 0;

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Marketing Campaigns</h2>
        <Link
          href="/admin/marketing/campaigns/new"
          className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          + Create Campaign
        </Link>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Campaigns</div>
          <div className="text-2xl font-bold text-zinc-900">
            {campaigns?.length || 0}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Active Campaigns</div>
          <div className="text-2xl font-bold text-emerald-600">
            {activeCampaigns.length}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Impressions</div>
          <div className="text-2xl font-bold text-zinc-900">
            {totalImpressions.toLocaleString()}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Conversions</div>
          <div className="text-2xl font-bold text-emerald-600">
            {totalConversions}
          </div>
        </div>
      </div>

      {/* Campaigns Table */}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Promo Code</th>
              <th className="px-4 py-3 font-medium">Performance</th>
              <th className="px-4 py-3 font-medium">Dates</th>
              <th className="px-4 py-3 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {campaigns && campaigns.length > 0 ? (
              campaigns.map((campaign) => {
                const perf = performance?.find((p) => p.id === campaign.id);
                const ctr = perf?.ctr_percentage || 0;
                const conversionRate = perf?.conversion_rate || 0;
                
                return (
                  <tr key={campaign.id} className="text-zinc-700 hover:bg-zinc-50">
                    <td className="px-4 py-3">
                      <Link
                        href={`/admin/marketing/campaigns/${campaign.id}`}
                        className="font-semibold text-emerald-600 hover:underline"
                      >
                        {campaign.name}
                      </Link>
                      {campaign.description && (
                        <div className="text-xs text-zinc-500 mt-1">
                          {campaign.description}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className="inline-block rounded px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700">
                        {campaign.campaign_type}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-block rounded px-2 py-1 text-xs font-medium ${
                          campaign.status === "active"
                            ? "bg-emerald-100 text-emerald-700"
                            : campaign.status === "completed"
                            ? "bg-zinc-100 text-zinc-600"
                            : campaign.status === "scheduled"
                            ? "bg-blue-100 text-blue-700"
                            : campaign.status === "paused"
                            ? "bg-yellow-100 text-yellow-700"
                            : "bg-zinc-100 text-zinc-600"
                        }`}
                      >
                        {campaign.status}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {campaign.promo_codes ? (
                        <Link
                          href={`/admin/marketing/promo-codes/${campaign.promo_code_id}`}
                          className="font-mono text-xs text-emerald-600 hover:underline"
                        >
                          {campaign.promo_codes.code}
                        </Link>
                      ) : (
                        <span className="text-zinc-500">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs">
                      <div>Impressions: {campaign.impressions_count || 0}</div>
                      <div>Clicks: {campaign.clicks_count || 0} ({ctr.toFixed(1)}%)</div>
                      <div>Conversions: {campaign.conversions_count || 0} ({conversionRate.toFixed(1)}%)</div>
                    </td>
                    <td className="px-4 py-3 text-xs">
                      {campaign.start_date && (
                        <div>Start: {new Date(campaign.start_date).toLocaleDateString()}</div>
                      )}
                      {campaign.end_date && (
                        <div>End: {new Date(campaign.end_date).toLocaleDateString()}</div>
                      )}
                      {!campaign.start_date && !campaign.end_date && (
                        <span className="text-zinc-500">No dates set</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <Link
                        href={`/admin/marketing/campaigns/${campaign.id}`}
                        className="text-emerald-600 hover:underline text-sm"
                      >
                        View Details
                      </Link>
                    </td>
                  </tr>
                );
              })
            ) : (
              <tr>
                <td className="px-4 py-6 text-sm text-zinc-500" colSpan={7}>
                  No campaigns yet. Create your first campaign to start engaging users!
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="rounded border border-blue-200 bg-blue-50 p-4">
        <p className="text-sm text-blue-800">
          <strong>Marketing Campaigns:</strong> Create targeted campaigns to promote your promo codes,
          engage users with push notifications, and track performance with built-in analytics.
        </p>
      </div>
    </section>
  );
}
