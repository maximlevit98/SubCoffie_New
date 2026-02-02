import Link from "next/link";
import { getPromoCodeById, getPromoUsage } from "@/lib/supabase/queries/marketing";
import { togglePromoCodeStatus, deletePromoCode } from "../../actions";

export default async function PromoCodeDetailPage({ params }: { params: { id: string } }) {
  const { data: promoCode, error } = await getPromoCodeById(params.id);
  const { data: usage } = await getPromoUsage(params.id);

  if (error || !promoCode) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Promo Code Not Found</h2>
        <p className="text-zinc-600">{error || "Could not find the requested promo code."}</p>
        <Link
          href="/admin/marketing/promo-codes"
          className="text-emerald-600 hover:underline"
        >
          ← Back to Promo Codes
        </Link>
      </section>
    );
  }

  const isExpired = promoCode.valid_until && new Date(promoCode.valid_until) < new Date();
  const maxReached = promoCode.max_uses && promoCode.uses_count >= promoCode.max_uses;
  const totalDiscountGiven = usage?.reduce((sum, u) => sum + (u.discount_applied || 0), 0) || 0;
  const totalRevenue = usage?.reduce((sum, u) => sum + (u.final_amount || 0), 0) || 0;

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold font-mono">{promoCode.code}</h2>
          <p className="text-sm text-zinc-600 mt-1">{promoCode.description || "No description"}</p>
        </div>
        <Link
          href="/admin/marketing/promo-codes"
          className="text-sm text-zinc-600 hover:text-zinc-900"
        >
          ← Back to Promo Codes
        </Link>
      </div>

      {/* Status Banner */}
      {(isExpired || maxReached || !promoCode.active) && (
        <div className="rounded border border-orange-200 bg-orange-50 p-4">
          <p className="text-sm text-orange-800">
            <strong>Status:</strong>{" "}
            {isExpired && "This promo code has expired. "}
            {maxReached && "This promo code has reached its maximum usage limit. "}
            {!promoCode.active && "This promo code is currently inactive."}
          </p>
        </div>
      )}

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Total Uses</div>
          <div className="text-2xl font-bold text-zinc-900">
            {usage?.length || 0}
          </div>
          {promoCode.max_uses && (
            <div className="text-xs text-zinc-500 mt-1">
              of {promoCode.max_uses} max
            </div>
          )}
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Discount Given</div>
          <div className="text-2xl font-bold text-orange-600">
            {totalDiscountGiven.toLocaleString()} ₽
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Revenue Generated</div>
          <div className="text-2xl font-bold text-emerald-600">
            {totalRevenue.toLocaleString()} ₽
          </div>
        </div>
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="text-sm text-zinc-600">Unique Users</div>
          <div className="text-2xl font-bold text-zinc-900">
            {new Set(usage?.map((u) => u.user_id)).size || 0}
          </div>
        </div>
      </div>

      {/* Details Card */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
        <h3 className="text-lg font-semibold">Promo Code Details</h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-zinc-600">Discount Type:</span>
            <div className="font-medium mt-1">
              <span className="inline-block rounded px-2 py-1 text-xs bg-blue-100 text-blue-700">
                {promoCode.discount_type}
              </span>
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Discount Value:</span>
            <div className="font-medium mt-1">
              {promoCode.discount_type === "percentage"
                ? `${promoCode.discount_value}%`
                : `${promoCode.discount_value} ₽`}
              {promoCode.max_discount_amount && (
                <span className="text-xs text-zinc-500 ml-2">
                  (max {promoCode.max_discount_amount} ₽)
                </span>
              )}
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Min Order Amount:</span>
            <div className="font-medium mt-1">{promoCode.min_order_amount || 0} ₽</div>
          </div>
          <div>
            <span className="text-zinc-600">Max Uses Per User:</span>
            <div className="font-medium mt-1">{promoCode.max_uses_per_user || "Unlimited"}</div>
          </div>
          <div>
            <span className="text-zinc-600">Valid From:</span>
            <div className="font-medium mt-1">
              {new Date(promoCode.valid_from).toLocaleDateString()}
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Valid Until:</span>
            <div className="font-medium mt-1">
              {promoCode.valid_until
                ? new Date(promoCode.valid_until).toLocaleDateString()
                : "No expiry"}
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Status:</span>
            <div className="font-medium mt-1">
              <span
                className={`inline-block rounded px-2 py-1 text-xs font-medium ${
                  promoCode.active && !isExpired && !maxReached
                    ? "bg-emerald-100 text-emerald-700"
                    : "bg-zinc-100 text-zinc-600"
                }`}
              >
                {promoCode.active && !isExpired && !maxReached ? "Active" : "Inactive"}
              </span>
            </div>
          </div>
          <div>
            <span className="text-zinc-600">Created:</span>
            <div className="font-medium mt-1">
              {new Date(promoCode.created_at).toLocaleDateString()}
            </div>
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-3">
        <form action={togglePromoCodeStatus}>
          <input type="hidden" name="id" value={promoCode.id} />
          <input type="hidden" name="active" value={(!promoCode.active).toString()} />
          <button
            type="submit"
            className={`rounded-lg px-4 py-2 text-sm font-medium ${
              promoCode.active
                ? "border border-zinc-300 hover:bg-zinc-50"
                : "bg-emerald-600 text-white hover:bg-emerald-700"
            }`}
          >
            {promoCode.active ? "Deactivate" : "Activate"}
          </button>
        </form>
        
        <form action={deletePromoCode} onSubmit={(e) => {
          if (!confirm("Are you sure you want to delete this promo code? This action cannot be undone.")) {
            e.preventDefault();
          }
        }}>
          <input type="hidden" name="id" value={promoCode.id} />
          <input type="hidden" name="confirm" value="yes" />
          <button
            type="submit"
            className="rounded-lg border border-red-300 px-4 py-2 text-sm font-medium text-red-600 hover:bg-red-50"
          >
            Delete
          </button>
        </form>
      </div>

      {/* Usage History */}
      {usage && usage.length > 0 && (
        <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
          <table className="min-w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
              <tr>
                <th className="px-4 py-3 font-medium">User Email</th>
                <th className="px-4 py-3 font-medium">Order ID</th>
                <th className="px-4 py-3 font-medium">Original Amount</th>
                <th className="px-4 py-3 font-medium">Discount</th>
                <th className="px-4 py-3 font-medium">Final Amount</th>
                <th className="px-4 py-3 font-medium">Used At</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {usage.map((u) => (
                <tr key={u.id} className="text-zinc-700 hover:bg-zinc-50">
                  <td className="px-4 py-3 text-xs">
                    {u.users?.email || "Unknown"}
                  </td>
                  <td className="px-4 py-3">
                    {u.order_id ? (
                      <Link
                        href={`/admin/orders/${u.order_id}`}
                        className="font-mono text-xs text-emerald-600 hover:underline"
                      >
                        {u.order_id.substring(0, 8)}...
                      </Link>
                    ) : (
                      <span className="text-zinc-500">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3 font-mono">
                    {u.original_amount?.toLocaleString() || 0} ₽
                  </td>
                  <td className="px-4 py-3 font-mono text-orange-600">
                    -{u.discount_applied?.toLocaleString() || 0} ₽
                  </td>
                  <td className="px-4 py-3 font-mono font-medium">
                    {u.final_amount?.toLocaleString() || 0} ₽
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-600">
                    {new Date(u.used_at).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {(!usage || usage.length === 0) && (
        <div className="rounded border border-zinc-200 bg-white p-6 text-center text-sm text-zinc-500">
          No usage history yet. Share this promo code with your users!
        </div>
      )}
    </section>
  );
}
