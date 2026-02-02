"use client";

import { useState } from "react";

type MenuItem = {
  id: string;
  name: string;
  category: string;
  price_credits: number;
  is_active: boolean;
  stop_reason?: string;
};

export default function StopListTable({
  menuItems,
  cafeId,
}: {
  menuItems: MenuItem[];
  cafeId: string;
}) {
  const [items, setItems] = useState(menuItems);
  const [loading, setLoading] = useState<string | null>(null);
  const [editingReason, setEditingReason] = useState<string | null>(null);
  const [reasonText, setReasonText] = useState("");
  const [filter, setFilter] = useState<"all" | "active" | "stopped">("all");

  const categoryLabels: { [key: string]: string } = {
    drinks: "☕ Напитки",
    food: "🍞 Еда",
    syrups: "🍯 Сиропы",
    merch: "🎁 Товары",
  };

  const toggleAvailability = async (itemId: string, currentStatus: boolean) => {
    setLoading(itemId);
    try {
      const response = await fetch("/api/cafe-owner/toggle-item", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          item_id: itemId,
          is_active: !currentStatus,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || "Failed to toggle item");
      }

      setItems((prev) =>
        prev.map((item) =>
          item.id === itemId
            ? {
                ...item,
                is_active: !currentStatus,
                stop_reason: !currentStatus ? null : item.stop_reason,
              }
            : item
        )
      );
    } catch (error: any) {
      alert(`Ошибка: ${error.message}`);
    } finally {
      setLoading(null);
    }
  };

  const updateStopReason = async (itemId: string) => {
    setLoading(itemId);
    try {
      const response = await fetch("/api/cafe-owner/update-stop-reason", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          item_id: itemId,
          stop_reason: reasonText,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || "Failed to update stop reason");
      }

      setItems((prev) =>
        prev.map((item) =>
          item.id === itemId
            ? {
                ...item,
                stop_reason: reasonText,
                is_active: !reasonText,
              }
            : item
        )
      );

      setEditingReason(null);
      setReasonText("");
    } catch (error: any) {
      alert(`Ошибка: ${error.message}`);
    } finally {
      setLoading(null);
    }
  };

  const startEditingReason = (itemId: string, currentReason?: string) => {
    setEditingReason(itemId);
    setReasonText(currentReason || "");
  };

  const filteredItems = items.filter((item) => {
    if (filter === "active") return item.is_active;
    if (filter === "stopped") return !item.is_active;
    return true;
  });

  const groupedItems = filteredItems.reduce((acc, item) => {
    if (!acc[item.category]) {
      acc[item.category] = [];
    }
    acc[item.category].push(item);
    return acc;
  }, {} as { [key: string]: MenuItem[] });

  return (
    <div className="space-y-6">
      {/* Filter Tabs */}
      <div className="flex gap-2 border-b border-zinc-200">
        <button
          onClick={() => setFilter("all")}
          className={`px-4 py-2 text-sm font-medium ${
            filter === "all"
              ? "border-b-2 border-blue-600 text-blue-600"
              : "text-zinc-600 hover:text-zinc-900"
          }`}
        >
          Все ({items.length})
        </button>
        <button
          onClick={() => setFilter("active")}
          className={`px-4 py-2 text-sm font-medium ${
            filter === "active"
              ? "border-b-2 border-green-600 text-green-600"
              : "text-zinc-600 hover:text-zinc-900"
          }`}
        >
          Доступно ({items.filter((i) => i.is_active).length})
        </button>
        <button
          onClick={() => setFilter("stopped")}
          className={`px-4 py-2 text-sm font-medium ${
            filter === "stopped"
              ? "border-b-2 border-red-600 text-red-600"
              : "text-zinc-600 hover:text-zinc-900"
          }`}
        >
          В стоп-листе ({items.filter((i) => !i.is_active).length})
        </button>
      </div>

      {/* Items by Category */}
      {Object.entries(groupedItems).map(([category, categoryItems]) => (
        <div key={category} className="rounded-lg border border-zinc-200 bg-white">
          <div className="border-b border-zinc-200 bg-zinc-50 px-6 py-3">
            <h3 className="font-semibold text-zinc-900">
              {categoryLabels[category] || category}
            </h3>
          </div>
          <div className="divide-y divide-zinc-100">
            {categoryItems.map((item) => (
              <div
                key={item.id}
                className={`px-6 py-4 ${
                  !item.is_active ? "bg-red-50" : ""
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3">
                      <h4 className="font-medium text-zinc-900">
                        {item.name}
                      </h4>
                      <span className="text-sm text-zinc-500">
                        {item.price_credits} кр.
                      </span>
                      {!item.is_active && (
                        <span className="rounded-full bg-red-100 px-2 py-1 text-xs font-medium text-red-800">
                          В стоп-листе
                        </span>
                      )}
                      {item.is_active && (
                        <span className="rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-800">
                          Доступно
                        </span>
                      )}
                    </div>
                    {item.stop_reason && (
                      <p className="mt-2 text-sm text-red-700">
                        <strong>Причина:</strong> {item.stop_reason}
                      </p>
                    )}
                    {editingReason === item.id && (
                      <div className="mt-3 flex gap-2">
                        <input
                          type="text"
                          value={reasonText}
                          onChange={(e) => setReasonText(e.target.value)}
                          placeholder="Причина недоступности..."
                          className="flex-1 rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                        />
                        <button
                          onClick={() => updateStopReason(item.id)}
                          disabled={loading === item.id}
                          className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                        >
                          {loading === item.id ? "..." : "Сохранить"}
                        </button>
                        <button
                          onClick={() => {
                            setEditingReason(null);
                            setReasonText("");
                          }}
                          className="rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
                        >
                          Отмена
                        </button>
                      </div>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    {!item.is_active && editingReason !== item.id && (
                      <button
                        onClick={() =>
                          startEditingReason(item.id, item.stop_reason)
                        }
                        className="rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
                      >
                        ✏️ Причина
                      </button>
                    )}
                    <button
                      onClick={() => toggleAvailability(item.id, item.is_active)}
                      disabled={loading === item.id || editingReason === item.id}
                      className={`rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-50 ${
                        item.is_active
                          ? "bg-red-600 hover:bg-red-700"
                          : "bg-green-600 hover:bg-green-700"
                      }`}
                    >
                      {loading === item.id
                        ? "..."
                        : item.is_active
                        ? "🚫 Отключить"
                        : "✅ Включить"}
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}

      {filteredItems.length === 0 && (
        <div className="rounded-lg border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <p className="text-zinc-500">Нет позиций для отображения</p>
        </div>
      )}
    </div>
  );
}
