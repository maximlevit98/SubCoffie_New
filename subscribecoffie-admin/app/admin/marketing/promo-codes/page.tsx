import Link from "next/link";
import { listPromoCodes, getPromoCodesSummary } from "@/lib/supabase/queries/marketing";

export default async function PromoCodesPage() {
  const { data: promoCodes, error } = await listPromoCodes(true); // Include inactive
  const { data: summary } = await getPromoCodesSummary();

  if (error) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Promo Codes</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Failed to load promo codes: {error}
        </p>
      </section>
    );
  }

  const activeCodes = promoCodes?.filter((pc) => pc.active) || [];
  const totalUsage = summary?.reduce((sum, s) => sum + (s.total_uses || 0), 0) || 0;
  const totalDiscountGiven = summary?.reduce((sum, s) => sum + (s.total_discount_given || 0), 0) || 0;

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Promo Codes</h2>
        <Link
          href="/admin/marketing/promo-codes/new"
          className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          + Create Promo Code
        </Link>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Codes</div>
          <div className="text-2xl font-bold text-zinc-900">
            {promoCodes?.length || 0}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Active Codes</div>
          <div className="text-2xl font-bold text-emerald-600">
            {activeCodes.length}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Uses</div>
          <div className="text-2xl font-bold text-zinc-900">
            {totalUsage}
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Discount Given</div>
          <div className="text-2xl font-bold text-orange-600">
            {totalDiscountGiven.toLocaleString()} ₽
          </div>
        </div>
      </div>

      {/* Promo Codes Table */}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Code</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Discount</th>
              <th className="px-4 py-3 font-medium">Uses</th>
              <th className="px-4 py-3 font-medium">Valid Until</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {promoCodes && promoCodes.length > 0 ? (
              promoCodes.map((promo) => {
                const isExpired = promo.valid_until && new Date(promo.valid_until) < new Date();
                const maxReached = promo.max_uses && promo.uses_count >= promo.max_uses;
                
                return (
                  <tr key={promo.id} className="text-zinc-700 hover:bg-zinc-50">
                    <td className="px-4 py-3">
                      <Link
                        href={`/admin/marketing/promo-codes/${promo.id}`}
                        className="font-mono font-semibold text-emerald-600 hover:underline"
                      >
                        {promo.code}
                      </Link>
                      {promo.description && (
                        <div className="text-xs text-zinc-500">{promo.description}</div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className="inline-block rounded px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700">
                        {promo.discount_type}
                      </span>
                    </td>
                    <td className="px-4 py-3 font-medium">
                      {promo.discount_type === "percentage"
                        ? `${promo.discount_value}%`
                        : `${promo.discount_value} ₽`}
                      {promo.max_discount_amount && (
                        <div className="text-xs text-zinc-500">
                          cap: {promo.max_discount_amount} ₽
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {promo.uses_count || 0}
                      {promo.max_uses && ` / ${promo.max_uses}`}
                      {maxReached && (
                        <div className="text-xs text-red-600 font-medium">Max reached</div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs">
                      {promo.valid_until ? (
                        <>
                          {new Date(promo.valid_until).toLocaleDateString()}
                          {isExpired && (
                            <div className="text-red-600 font-medium">Expired</div>
                          )}
                        </>
                      ) : (
                        <span className="text-zinc-500">No expiry</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-block rounded px-2 py-1 text-xs font-medium ${
                          promo.active && !isExpired && !maxReached
                            ? "bg-emerald-100 text-emerald-700"
                            : "bg-zinc-100 text-zinc-600"
                        }`}
                      >
                        {promo.active && !isExpired && !maxReached ? "Active" : "Inactive"}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <Link
                        href={`/admin/marketing/promo-codes/${promo.id}`}
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
                  No promo codes yet. Create your first one!
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="rounded border border-blue-200 bg-blue-50 p-4">
        <p className="text-sm text-blue-800">
          <strong>Tip:</strong> Create targeted promo codes to drive conversions, reward loyal customers,
          or attract new users. Monitor performance and adjust your strategy accordingly.
        </p>
      </div>
    </section>
  );
}
