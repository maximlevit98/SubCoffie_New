"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { addManualTransaction } from "../actions";

type AddTransactionFormProps = {
  userId: string;
};

export function AddTransactionForm({ userId }: AddTransactionFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const [formData, setFormData] = useState({
    type: "credit" as "credit" | "debit",
    amount: "",
    reason: "",
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(false);

    try {
      const amount = parseInt(formData.amount, 10);

      if (isNaN(amount) || amount <= 0) {
        throw new Error("Сумма должна быть положительным числом");
      }

      if (!formData.reason.trim()) {
        throw new Error("Укажите причину операции");
      }

      await addManualTransaction(
        userId,
        amount,
        formData.type,
        formData.reason
      );

      setSuccess(true);
      setFormData({ type: "credit", amount: "", reason: "" });
      router.refresh();

      // Убираем сообщение об успехе через 3 секунды
      setTimeout(() => setSuccess(false), 3000);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {/* Type Selector */}
      <div>
        <label className="block text-sm font-medium text-zinc-700 mb-2">
          Тип операции
        </label>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => setFormData({ ...formData, type: "credit" })}
            className={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              formData.type === "credit"
                ? "bg-green-600 text-white"
                : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
            }`}
          >
            ✚ Начислить
          </button>
          <button
            type="button"
            onClick={() => setFormData({ ...formData, type: "debit" })}
            className={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              formData.type === "debit"
                ? "bg-red-600 text-white"
                : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
            }`}
          >
            ✖ Списать
          </button>
        </div>
      </div>

      {/* Amount */}
      <div>
        <label
          htmlFor="amount"
          className="block text-sm font-medium text-zinc-700 mb-2"
        >
          Сумма (кредиты)
        </label>
        <input
          id="amount"
          type="number"
          min="1"
          step="1"
          value={formData.amount}
          onChange={(e) =>
            setFormData({ ...formData, amount: e.target.value })
          }
          className="w-full px-3 py-2 border border-zinc-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="100"
          required
        />
      </div>

      {/* Reason */}
      <div>
        <label
          htmlFor="reason"
          className="block text-sm font-medium text-zinc-700 mb-2"
        >
          Причина операции
        </label>
        <textarea
          id="reason"
          value={formData.reason}
          onChange={(e) =>
            setFormData({ ...formData, reason: e.target.value })
          }
          className="w-full px-3 py-2 border border-zinc-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          rows={3}
          placeholder="Промо-акция / компенсация / корректировка баланса"
          required
        />
      </div>

      {/* Submit Button */}
      <div className="flex items-center gap-3">
        <button
          type="submit"
          disabled={loading}
          className={`px-6 py-2 rounded-md text-sm font-medium text-white transition-colors ${
            formData.type === "credit"
              ? "bg-green-600 hover:bg-green-700"
              : "bg-red-600 hover:bg-red-700"
          } disabled:opacity-50 disabled:cursor-not-allowed`}
        >
          {loading
            ? "Обработка..."
            : formData.type === "credit"
            ? "Начислить средства"
            : "Списать средства"}
        </button>

        {success && (
          <span className="text-sm text-green-600 font-medium">
            ✓ Операция выполнена успешно
          </span>
        )}
      </div>

      {/* Error Message */}
      {error && (
        <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}
    </form>
  );
}
