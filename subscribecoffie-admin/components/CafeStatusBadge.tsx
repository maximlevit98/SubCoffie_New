'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

interface CafeStatusBadgeProps {
  cafeId: string;
  currentStatus: 'draft' | 'moderation' | 'published' | 'paused' | 'rejected';
  readonly?: boolean;
}

const statusColors = {
  draft: 'bg-blue-100 text-blue-800 border-blue-200',
  moderation: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  published: 'bg-green-100 text-green-800 border-green-200',
  paused: 'bg-gray-100 text-gray-800 border-gray-200',
  rejected: 'bg-red-100 text-red-800 border-red-200',
};

const statusLabels = {
  draft: 'Черновик',
  moderation: 'На модерации',
  published: 'Опубликовано',
  paused: 'Приостановлено',
  rejected: 'Отклонено',
};

const statusOptions = [
  { value: 'draft', label: 'Черновик', icon: '📝' },
  { value: 'moderation', label: 'На модерации', icon: '⏳' },
  { value: 'published', label: 'Опубликовано', icon: '✅' },
  { value: 'paused', label: 'Приостановлено', icon: '⏸️' },
];

export function CafeStatusBadge({
  cafeId,
  currentStatus,
  readonly = false,
}: CafeStatusBadgeProps) {
  const router = useRouter();
  const [isOpen, setIsOpen] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);

  const handleStatusChange = async (
    newStatus: 'draft' | 'moderation' | 'published' | 'paused'
  ) => {
    if (newStatus === currentStatus) {
      setIsOpen(false);
      return;
    }

    setIsUpdating(true);

    try {
      const response = await fetch(`/api/owner/cafes/${cafeId}/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus }),
      });

      if (!response.ok) {
        throw new Error('Failed to update status');
      }

      // Refresh the page to show new status
      router.refresh();
      setIsOpen(false);
    } catch (error) {
      console.error('Status update error:', error);
      alert('Не удалось обновить статус');
    } finally {
      setIsUpdating(false);
    }
  };

  if (readonly) {
    return (
      <span
        className={`inline-flex rounded-full border px-2 py-1 text-xs font-medium ${statusColors[currentStatus]}`}
      >
        {statusLabels[currentStatus]}
      </span>
    );
  }

  return (
    <div className="relative">
      <button
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setIsOpen(!isOpen);
        }}
        disabled={isUpdating}
        className={`inline-flex items-center gap-1 rounded-full border px-2 py-1 text-xs font-medium transition-all hover:shadow-sm ${statusColors[currentStatus]} ${isUpdating ? 'opacity-50 cursor-wait' : 'cursor-pointer'}`}
      >
        <span>{statusLabels[currentStatus]}</span>
        <svg
          className={`h-3 w-3 transition-transform ${isOpen ? 'rotate-180' : ''}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>

      {isOpen && (
        <>
          <div
            className="fixed inset-0 z-10"
            onClick={(e) => {
              e.stopPropagation();
              setIsOpen(false);
            }}
          />
          <div className="absolute right-0 z-20 mt-2 w-56 rounded-lg border border-zinc-200 bg-white shadow-lg">
            <div className="p-2">
              <p className="mb-2 px-2 text-xs font-medium text-zinc-500">
                Изменить статус
              </p>
              {statusOptions.map((option) => (
                <button
                  key={option.value}
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    handleStatusChange(
                      option.value as 'draft' | 'moderation' | 'published' | 'paused'
                    );
                  }}
                  disabled={isUpdating}
                  className={`w-full rounded-lg px-3 py-2 text-left text-sm transition-colors ${
                    option.value === currentStatus
                      ? 'bg-blue-50 font-medium text-blue-900'
                      : 'text-zinc-700 hover:bg-zinc-50'
                  } ${isUpdating ? 'opacity-50 cursor-wait' : ''}`}
                >
                  <span className="flex items-center gap-2">
                    <span>{option.icon}</span>
                    <span>{option.label}</span>
                  </span>
                </button>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
