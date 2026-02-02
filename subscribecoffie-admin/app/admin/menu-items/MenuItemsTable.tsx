"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";

import type { MenuItemRecord } from "../../../lib/supabase/queries/menu-items";
import { updateMenuItemPrice } from "./actions";

type MenuItemsTableProps = {
  items: MenuItemRecord[];
  canEdit?: boolean;
  cafeId?: string;
};

export default function MenuItemsTable({
  items,
  canEdit = true,
  cafeId,
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
      {cafeId && (
        <div className="flex items-center justify-between rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3">
          <p className="text-sm text-zinc-700">
            📍 Позиций в меню: <strong>{rows.length}</strong>
          </p>
          {canEdit && (
            <Link
              href={`/admin/menu-items/new?cafe_id=${cafeId}`}
              className="rounded bg-zinc-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-zinc-800"
            >
              ➕ Добавить в это меню
            </Link>
          )}
        </div>
      )}
      <div className="overflow-x-auto rounded border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Название</th>
              <th className="px-4 py-3 font-medium">Категория</th>
              <th className="px-4 py-3 font-medium">Цена</th>
              <th className="px-4 py-3 font-medium">Доступность</th>
              <th className="px-4 py-3 font-medium">Порядок</th>
              {canEdit && <th className="px-4 py-3 font-medium">Действия</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {rows.map((item) => (
              <tr key={item.id} className="text-zinc-700 hover:bg-zinc-50">
                <td className="px-4 py-3">
                  <div>
                    <div className="font-medium">{item.name}</div>
                    {item.description && item.description !== "—" && (
                      <div className="mt-0.5 text-xs text-zinc-500">
                        {item.description}
                      </div>
                    )}
                  </div>
                </td>
                <td className="px-4 py-3">
                  <span className="rounded bg-zinc-100 px-2 py-1 text-xs font-medium">
                    {item.category}
                  </span>
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
                          {savingId === item.id ? "💾" : "Save"}
                        </button>
                      </>
                    ) : (
                      <span className="font-medium">{item.price_credits ?? "—"} ₽</span>
                    )}
                  </div>
                </td>
                <td className="px-4 py-3">
                  {item.is_available ? (
                    <span className="inline-flex items-center gap-1 text-emerald-600">
                      ✓ Да
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-red-600">
                      ✗ Нет
                    </span>
                  )}
                </td>
                <td className="px-4 py-3 text-zinc-500">
                  {item.sort_order ?? 0}
                </td>
                {canEdit && (
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <Link
                        href={`/admin/menu-items/${item.id}`}
                        className="rounded border border-zinc-300 px-2 py-1 text-xs hover:bg-zinc-50"
                      >
                        Редактировать
                      </Link>
                    </div>
                  </td>
                )}
              </tr>
            ))}
            {!hasRows && (
              <tr>
                <td
                  className="px-4 py-8 text-center text-sm text-zinc-500"
                  colSpan={canEdit ? 6 : 5}
                >
                  Позиции меню не найдены
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
