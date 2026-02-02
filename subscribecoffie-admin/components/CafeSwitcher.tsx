'use client';

import { useRouter, usePathname } from 'next/navigation';
import { useState } from 'react';

interface Cafe {
  id: string;
  name: string;
  status: 'draft' | 'moderation' | 'published' | 'paused' | 'rejected';
  address?: string;
}

interface CafeSwitcherProps {
  currentCafeId: string;
  cafes: Cafe[];
}

const statusColors = {
  draft: 'bg-blue-100 text-blue-800',
  moderation: 'bg-yellow-100 text-yellow-800',
  published: 'bg-green-100 text-green-800',
  paused: 'bg-gray-100 text-gray-800',
  rejected: 'bg-red-100 text-red-800',
};

const statusLabels = {
  draft: 'Черновик',
  moderation: 'Модерация',
  published: 'Опубликовано',
  paused: 'Приостановлено',
  rejected: 'Отклонено',
};

export function CafeSwitcher({ currentCafeId, cafes }: CafeSwitcherProps) {
  const router = useRouter();
  const pathname = usePathname();
  const [isOpen, setIsOpen] = useState(false);

  const currentCafe = cafes.find((cafe) => cafe.id === currentCafeId);

  const handleSwitch = (newCafeId: string) => {
    if (newCafeId === currentCafeId) {
      setIsOpen(false);
      return;
    }

    // Replace cafe_id in pathname
    const newPath = pathname.replace(
      `/cafe/${currentCafeId}`,
      `/cafe/${newCafeId}`
    );
    router.push(newPath);
    setIsOpen(false);
  };

  const handleCreateNew = () => {
    router.push('/admin/owner/cafes/new');
    setIsOpen(false);
  };

  if (!currentCafe) {
    return null;
  }

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 rounded-lg border border-zinc-200 bg-white px-4 py-2 text-sm font-medium text-zinc-900 shadow-sm hover:bg-zinc-50 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <span className="max-w-[200px] truncate">{currentCafe.name}</span>
        <svg
          className={`h-4 w-4 text-zinc-400 transition-transform ${isOpen ? 'rotate-180' : ''}`}
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
            onClick={() => setIsOpen(false)}
          />
          <div className="absolute right-0 z-20 mt-2 w-80 rounded-lg border border-zinc-200 bg-white shadow-lg">
            <div className="max-h-96 overflow-y-auto p-2">
              {cafes.map((cafe) => (
                <button
                  key={cafe.id}
                  onClick={() => handleSwitch(cafe.id)}
                  className={`w-full rounded-lg px-3 py-2.5 text-left transition-colors ${
                    cafe.id === currentCafeId
                      ? 'bg-blue-50'
                      : 'hover:bg-zinc-50'
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <p
                        className={`truncate text-sm font-medium ${
                          cafe.id === currentCafeId
                            ? 'text-blue-900'
                            : 'text-zinc-900'
                        }`}
                      >
                        {cafe.name}
                      </p>
                      {cafe.address && (
                        <p className="mt-0.5 truncate text-xs text-zinc-500">
                          {cafe.address}
                        </p>
                      )}
                    </div>
                    <span
                      className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ${statusColors[cafe.status]}`}
                    >
                      {statusLabels[cafe.status]}
                    </span>
                  </div>
                </button>
              ))}
            </div>
            <div className="border-t border-zinc-200 p-2">
              <button
                onClick={handleCreateNew}
                className="w-full rounded-lg px-3 py-2 text-left text-sm font-medium text-blue-600 hover:bg-blue-50"
              >
                + Создать новую кофейню
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
