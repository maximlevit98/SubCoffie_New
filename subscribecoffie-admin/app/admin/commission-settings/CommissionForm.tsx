"use client";

import { useTransition, useState } from "react";
import { updateCommissionRate } from "../../../lib/supabase/queries/payments";
import { revalidatePath } from "next/cache";

type CommissionFormProps = {
  operationType: string;
  currentRate: number;
};

export default function CommissionForm({
  operationType,
  currentRate,
}: CommissionFormProps) {
  const [isPending, startTransition] = useTransition();
  const [rate, setRate] = useState(currentRate.toString());
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    const newRate = parseFloat(rate);
    if (isNaN(newRate) || newRate < 0 || newRate > 100) {
      setError("Rate must be between 0 and 100");
      return;
    }

    startTransition(async () => {
      try {
        const { error: updateError } = await updateCommissionRate(
          operationType,
          newRate
        );

        if (updateError) {
          setError(updateError);
        } else {
          // Success - page will revalidate
          window.location.reload();
        }
      } catch (err) {
        setError((err as Error).message);
      }
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      {error && (
        <div className="rounded border border-red-200 bg-red-50 p-2 text-xs text-red-700">
          {error}
        </div>
      )}

      <div>
        <label className="text-xs text-zinc-600">
          New Rate (%)
          <input
            type="number"
            step="0.01"
            min="0"
            max="100"
            value={rate}
            onChange={(e) => setRate(e.target.value)}
            className="mt-1 w-full rounded border border-zinc-300 px-3 py-2 text-sm"
            disabled={isPending}
          />
        </label>
      </div>

      <button
        type="submit"
        disabled={isPending || parseFloat(rate) === currentRate}
        className="w-full rounded bg-blue-500 px-4 py-2 text-sm font-medium text-white disabled:opacity-50 hover:bg-blue-600"
      >
        {isPending ? "Updating..." : "Update Rate"}
      </button>
    </form>
  );
}
