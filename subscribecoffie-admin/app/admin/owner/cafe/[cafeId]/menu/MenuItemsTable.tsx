'use client';

import Link from 'next/link';
import { useState } from 'react';

type MenuItem = {
  id: string;
  name: string;
  title: string;
  description: string;
  price_credits: number;
  prep_time_sec: number;
  is_available: boolean;
  sort_order: number;
  category: string;
};

type MenuItemsTableProps = {
  items: MenuItem[];
  cafeId: string;
};

export function MenuItemsTable({ items, cafeId }: MenuItemsTableProps) {
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [togglingId, setTogglingId] = useState<string | null>(null);

  const handleDelete = async (itemId: string) => {
    if (!confirm('Вы уверены, что хотите удалить эту позицию?')) {
      return;
    }

    setDeletingId(itemId);

    try {
      const response = await fetch(`/api/owner/menu-items/${itemId}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        throw new Error('Failed to delete');
      }

      window.location.reload();
    } catch (error) {
      console.error('Delete error:', error);
      alert('Не удалось удалить позицию');
      setDeletingId(null);
    }
  };

  const handleToggleAvailability = async (itemId: string, currentStatus: boolean) => {
    setTogglingId(itemId);
    try {
      const response = await fetch(`/api/owner/menu-items/${itemId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ is_available: !currentStatus }),
      });

      if (!response.ok) {
        throw new Error('Failed to update');
      }

      window.location.reload();
    } catch (error) {
      console.error('Update error:', error);
      alert('Не удалось обновить статус');
      setTogglingId(null);
    }
  };

  return (
    <div className="space-y-2">
      {items.map((item) => (
        <div
          key={item.id}
          className="group relative flex items-center gap-4 rounded-lg border border-zinc-200 bg-white p-4 transition-all hover:border-zinc-300 hover:shadow-sm"
        >
          {/* Status Indicator */}
          <div
            className={`h-full w-1 absolute left-0 top-0 bottom-0 rounded-l-lg ${
              item.is_available ? 'bg-green-500' : 'bg-zinc-300'
            }`}
          />

          {/* Main Content */}
          <div className="flex-1 min-w-0 pl-3">
            <div className="flex items-start justify-between gap-4">
              {/* Title & Description */}
              <div className="flex-1 min-w-0">
                <h4 className="text-sm font-semibold text-zinc-900">
                  {item.name || item.title}
                </h4>
                <p className="mt-1 text-xs text-zinc-500 line-clamp-1">
                  {item.description}
                </p>
              </div>

              {/* Price & Time */}
              <div className="flex items-center gap-4 text-sm">
                <div className="flex items-center gap-1 text-zinc-700">
                  <span className="font-semibold">{item.price_credits}</span>
                  <span className="text-xs text-zinc-500">кр</span>
                </div>
                <div className="flex items-center gap-1 text-zinc-500">
                  <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span className="text-xs">{Math.round(item.prep_time_sec / 60)} мин</span>
                </div>
              </div>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-2">
            {/* Toggle Availability */}
            <button
              onClick={() => handleToggleAvailability(item.id, item.is_available)}
              disabled={togglingId === item.id}
              className={`rounded-md px-3 py-1.5 text-xs font-medium transition-colors ${
                item.is_available
                  ? 'bg-green-100 text-green-700 hover:bg-green-200'
                  : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
              } disabled:opacity-50`}
              title={item.is_available ? 'Скрыть из меню' : 'Показать в меню'}
            >
              {togglingId === item.id ? (
                '...'
              ) : item.is_available ? (
                <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                  <path fillRule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clipRule="evenodd" />
                </svg>
              ) : (
                <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M3.707 2.293a1 1 0 00-1.414 1.414l14 14a1 1 0 001.414-1.414l-1.473-1.473A10.014 10.014 0 0019.542 10C18.268 5.943 14.478 3 10 3a9.958 9.958 0 00-4.512 1.074l-1.78-1.781zm4.261 4.26l1.514 1.515a2.003 2.003 0 012.45 2.45l1.514 1.514a4 4 0 00-5.478-5.478z" clipRule="evenodd" />
                  <path d="M12.454 16.697L9.75 13.992a4 4 0 01-3.742-3.741L2.335 6.578A9.98 9.98 0 00.458 10c1.274 4.057 5.065 7 9.542 7 .847 0 1.669-.105 2.454-.303z" />
                </svg>
              )}
            </button>

            {/* Edit Button */}
            <Link
              href={`/admin/owner/cafe/${cafeId}/menu/${item.id}`}
              className="rounded-md bg-blue-50 p-1.5 text-blue-600 transition-colors hover:bg-blue-100"
              title="Редактировать"
            >
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </Link>

            {/* Delete Button */}
            <button
              onClick={() => handleDelete(item.id)}
              disabled={deletingId === item.id}
              className="rounded-md bg-red-50 p-1.5 text-red-600 transition-colors hover:bg-red-100 disabled:opacity-50"
              title="Удалить"
            >
              {deletingId === item.id ? (
                <svg className="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                </svg>
              ) : (
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              )}
            </button>
          </div>
        </div>
      ))}

      {items.length === 0 && (
        <div className="rounded-lg border-2 border-dashed border-zinc-200 p-8 text-center">
          <svg className="mx-auto h-12 w-12 text-zinc-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <p className="mt-2 text-sm text-zinc-500">
            Нет позиций в этой категории
          </p>
        </div>
      )}
    </div>
  );
}
