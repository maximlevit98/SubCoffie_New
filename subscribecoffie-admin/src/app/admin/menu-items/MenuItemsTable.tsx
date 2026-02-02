"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";

import type { MenuItemRecord } from "../../../lib/supabase/queries/menu-items";
import { updateMenuItemPrice } from "./actions";

type MenuItemsTableProps = {
  items: MenuItemRecord[];
  canEdit?: boolean;
};

export default function MenuItemsTable({
  items,
  canEdit = true,
}: MenuItemsTableProps) {
  const [rows, setRows] = useState<MenuItemRecord[]>(items);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const hasRows = useMemo(() => rows.length > 0, [rows.length]);

  const handlePriceChange = (id: string, value: string) => {
    const nextValue = value === "" ? null : Number(value);
    setRows((prev) =>
      prev.map((row) =>
        row.id === id ? { ...row, price_credits: nextValue } : row,
      ),
    );
  };

  const handleSave = (id: string) => {
    if (!canEdit) {
      return;
    }
    setError(null);
    setSavingId(id);

    const row = rows.find((item) => item.id === id);
    const nextPrice = row?.price_credits ?? null;

    startTransition(async () => {
      const result = await updateMenuItemPrice(id, nextPrice);
      if (!result.ok) {
        setError(result.error ?? "Не удалось обновить цену.");
      }
      setSavingId(null);
    });
  };

  return (
    <div className="space-y-3">
      {error && (
        <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Category</th>
              <th className="px-4 py-3 font-medium">Cafe</th>
              <th className="px-4 py-3 font-medium">Price</th>
              <th className="px-4 py-3 font-medium">Available</th>
              <th className="px-4 py-3 font-medium">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {rows.map((item) => (
              <tr key={item.id} className="text-zinc-700">
                <td className="px-4 py-3">{item.name}</td>
                <td className="px-4 py-3">{item.category}</td>
                <td className="px-4 py-3 font-mono text-xs">
                  {item.cafe_id}
                </td>
                <td className="px-4 py-3">
                  <div className="flex items-center gap-2">
                    {canEdit ? (
                      <>
                        <input
                          type="number"
                          step="1"
                          min="0"
                          value={item.price_credits ?? ""}
                          onChange={(event) =>
                            handlePriceChange(item.id, event.target.value)
                          }
                          className="w-24 rounded border border-zinc-300 px-2 py-1 text-xs"
                        />
                        <button
                          type="button"
                          onClick={() => handleSave(item.id)}
                          disabled={isPending && savingId === item.id}
                          className="rounded border border-zinc-300 px-2 py-1 text-xs hover:bg-zinc-50 disabled:opacity-60"
                        >
                          {savingId === item.id ? "Saving..." : "Save"}
                        </button>
                      </>
                    ) : (
                      <span>{item.price_credits ?? "—"}</span>
                    )}
                  </div>
                </td>
                <td className="px-4 py-3">
                  {item.is_available ? "Yes" : "No"}
                </td>
                <td className="px-4 py-3">
                  {canEdit ? (
                    <Link
                      href={`/admin/menu-items/${item.id}`}
                      className="rounded border border-zinc-300 px-3 py-1 text-xs font-medium hover:bg-zinc-50"
                    >
                      Open
                    </Link>
                  ) : (
                    <span className="text-xs text-zinc-400">Read-only</span>
                  )}
                </td>
              </tr>
            ))}
            {!hasRows && (
              <tr>
                <td className="px-4 py-6 text-sm text-zinc-500" colSpan={6}>
                  Menu items not found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
