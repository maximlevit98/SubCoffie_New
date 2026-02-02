import Link from "next/link";
import { createPromoCode } from "../../actions";

export default function NewPromoCodePage() {

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Create Promo Code</h2>
          <p className="text-sm text-zinc-600 mt-1">
            Set up a new promotional discount code for your users
          </p>
        </div>
        <Link
          href="/admin/marketing/promo-codes"
          className="text-sm text-zinc-600 hover:text-zinc-900"
        >
          ← Back to Promo Codes
        </Link>
      </div>

      <form action={createPromoCode} className="space-y-6">
        <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
          <h3 className="text-lg font-semibold">Basic Information</h3>
          
          <div>
            <label htmlFor="code" className="block text-sm font-medium text-zinc-700">
              Promo Code <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              id="code"
              name="code"
              required
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm font-mono uppercase"
              placeholder="SUMMER2026"
              pattern="[A-Z0-9]+"
              title="Only uppercase letters and numbers allowed"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Use uppercase letters and numbers only (e.g., SAVE20, WELCOME2026)
            </p>
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium text-zinc-700">
              Description
            </label>
            <textarea
              id="description"
              name="description"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              rows={2}
              placeholder="Summer promotion - 20% off all orders"
            />
          </div>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
          <h3 className="text-lg font-semibold">Discount Configuration</h3>
          
          <div>
            <label htmlFor="discount_type" className="block text-sm font-medium text-zinc-700">
              Discount Type <span className="text-red-500">*</span>
            </label>
            <select
              id="discount_type"
              name="discount_type"
              required
              defaultValue="percentage"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            >
              <option value="percentage">Percentage (%)</option>
              <option value="fixed_amount">Fixed Amount (₽)</option>
              <option value="free_item">Free Item</option>
            </select>
          </div>

          <div>
            <label htmlFor="discount_value" className="block text-sm font-medium text-zinc-700">
              Discount Value <span className="text-red-500">*</span>
            </label>
            <input
              type="number"
              id="discount_value"
              name="discount_value"
              required
              min="0"
              step="0.01"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="20"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Enter discount value (percentage or fixed amount in rubles)
            </p>
          </div>

          <div>
            <label htmlFor="max_discount_amount" className="block text-sm font-medium text-zinc-700">
              Max Discount Amount (₽)
            </label>
            <input
              type="number"
              id="max_discount_amount"
              name="max_discount_amount"
              min="0"
              step="0.01"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="500"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Optional: Cap the maximum discount amount (e.g., 20% off but max 500₽)
            </p>
          </div>

          <div>
            <label htmlFor="min_order_amount" className="block text-sm font-medium text-zinc-700">
              Minimum Order Amount (₽)
            </label>
            <input
              type="number"
              id="min_order_amount"
              name="min_order_amount"
              min="0"
              step="0.01"
              defaultValue="0"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="0"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Minimum order amount required to use this promo code
            </p>
          </div>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
          <h3 className="text-lg font-semibold">Usage Limits</h3>
          
          <div>
            <label htmlFor="max_uses" className="block text-sm font-medium text-zinc-700">
              Total Uses Limit
            </label>
            <input
              type="number"
              id="max_uses"
              name="max_uses"
              min="1"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="Unlimited"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Leave empty for unlimited uses
            </p>
          </div>

          <div>
            <label htmlFor="max_uses_per_user" className="block text-sm font-medium text-zinc-700">
              Uses Per User
            </label>
            <input
              type="number"
              id="max_uses_per_user"
              name="max_uses_per_user"
              min="1"
              defaultValue="1"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="1"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Maximum number of times each user can use this code
            </p>
          </div>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 space-y-4">
          <h3 className="text-lg font-semibold">Validity Period</h3>
          
          <div>
            <label htmlFor="valid_from" className="block text-sm font-medium text-zinc-700">
              Valid From
            </label>
            <input
              type="date"
              id="valid_from"
              name="valid_from"
              defaultValue={new Date().toISOString().split("T")[0]}
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            />
          </div>

          <div>
            <label htmlFor="valid_until" className="block text-sm font-medium text-zinc-700">
              Valid Until
            </label>
            <input
              type="date"
              id="valid_until"
              name="valid_until"
              className="mt-1 block w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            />
            <p className="mt-1 text-xs text-zinc-500">
              Leave empty for no expiry date
            </p>
          </div>
        </div>

        <div className="flex justify-end gap-3">
          <Link
            href="/admin/marketing/promo-codes"
            className="rounded-lg border border-zinc-300 px-6 py-2 text-sm font-medium hover:bg-zinc-50"
          >
            Cancel
          </Link>
          <button
            type="submit"
            className="rounded-lg bg-emerald-600 px-6 py-2 text-sm font-medium text-white hover:bg-emerald-700"
          >
            Create Promo Code
          </button>
        </div>
      </form>
    </section>
  );
}
