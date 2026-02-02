"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { updateOrderStatus } from "../actions";

type OrderStatusButtonsProps = {
  orderId: string;
  currentStatus: string;
  availableStatuses: string[];
};

export function OrderStatusButtons({
  orderId,
  currentStatus,
  availableStatuses,
}: OrderStatusButtonsProps) {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const statusLabels: Record<string, string> = {
    created: "Создан",
    paid: "Оплачен",
    preparing: "Готовится",
    ready: "Готов",
    issued: "Выдан",
    cancelled: "Отменён",
    refunded: "Возврат",
  };

  const statusColors: Record<string, string> = {
    created: "bg-zinc-600 hover:bg-zinc-700",
    paid: "bg-blue-600 hover:bg-blue-700",
    preparing: "bg-amber-600 hover:bg-amber-700",
    ready: "bg-emerald-600 hover:bg-emerald-700",
    issued: "bg-green-600 hover:bg-green-700",
    cancelled: "bg-red-600 hover:bg-red-700",
    refunded: "bg-purple-600 hover:bg-purple-700",
  };

  const handleStatusChange = async (newStatus: string) => {
    if (loading) return;

    const confirmed = confirm(
      `Изменить статус на "${statusLabels[newStatus]}"?`
    );
    if (!confirmed) return;

    setLoading(newStatus);
    setError(null);

    try {
      await updateOrderStatus(orderId, newStatus);
      router.refresh();
    } catch (e: any) {
      setError(e.message);
      console.error("Failed to update order status:", e);
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {availableStatuses.map((status) => (
          <button
            key={status}
            onClick={() => handleStatusChange(status)}
            disabled={loading !== null}
            className={`
              inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white
              transition-colors disabled:opacity-50 disabled:cursor-not-allowed
              ${statusColors[status] || "bg-zinc-600 hover:bg-zinc-700"}
            `}
          >
            {loading === status ? (
              <>
                <svg
                  className="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    className="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    strokeWidth="4"
                  ></circle>
                  <path
                    className="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                  ></path>
                </svg>
                Обновление...
              </>
            ) : (
              <>→ {statusLabels[status]}</>
            )}
          </button>
        ))}
      </div>

      {error && (
        <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Ошибка: {error}
        </div>
      )}
    </div>
  );
}
