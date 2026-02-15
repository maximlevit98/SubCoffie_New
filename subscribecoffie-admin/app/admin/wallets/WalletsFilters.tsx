"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState, useTransition } from "react";

type WalletsFiltersProps = {
  currentSearch?: string;
  currentType?: string;
  currentSort?: string;
  currentPage: number;
  currentLimit: number;
  totalResults: number;
  hasMore: boolean;
};

export function WalletsFilters({
  currentSearch,
  currentType,
  currentSort,
  currentPage,
  totalResults,
  hasMore,
}: WalletsFiltersProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [isPending, startTransition] = useTransition();
  
  const [search, setSearch] = useState(currentSearch || "");

  const updateFilters = (updates: Record<string, string | number | undefined>) => {
    const params = new URLSearchParams(searchParams.toString());
    
    Object.entries(updates).forEach(([key, value]) => {
      if (value !== undefined && value !== "" && value !== null) {
        params.set(key, String(value));
      } else {
        params.delete(key);
      }
    });
    
    // Reset page when filters change (except pagination actions)
    if (!updates.page && !updates.limit) {
      params.delete("page");
    }
    
    startTransition(() => {
      router.push(`/admin/wallets?${params.toString()}`);
    });
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    updateFilters({ search });
  };

  const handleTypeChange = (type: string) => {
    if (currentType === type) {
      updateFilters({ type: undefined });
    } else {
      updateFilters({ type });
    }
  };

  const handleSortChange = (sort: string) => {
    updateFilters({ sort });
  };

  const handlePageChange = (page: number) => {
    updateFilters({ page });
  };

  const handleClearAll = () => {
    setSearch("");
    router.push("/admin/wallets");
  };

  const hasActiveFilters = currentSearch || currentType || currentSort !== "created_at";

  return (
    <div className="space-y-4">
      {/* Main Filters Row */}
      <div className="rounded-lg border border-zinc-200 bg-white p-4">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold text-zinc-700">
            Фильтры и поиск
          </h3>
          {hasActiveFilters && (
            <button
              onClick={handleClearAll}
              className="text-xs text-zinc-500 hover:text-zinc-700 underline"
              disabled={isPending}
            >
              Сбросить всё
            </button>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Search */}
          <form onSubmit={handleSearchSubmit} className="md:col-span-2">
            <label
              htmlFor="search"
              className="block text-xs font-medium text-zinc-600 mb-2"
            >
              Поиск
            </label>
            <div className="flex gap-2">
              <input
                id="search"
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Email, телефон, имя, ID кошелька..."
                className="flex-1 px-3 py-2 border border-zinc-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                disabled={isPending}
              />
              <button
                type="submit"
                disabled={isPending}
                className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {isPending ? "..." : "Найти"}
              </button>
            </div>
          </form>

          {/* Sort */}
          <div>
            <label
              htmlFor="sort"
              className="block text-xs font-medium text-zinc-600 mb-2"
            >
              Сортировка
            </label>
            <select
              id="sort"
              value={currentSort || "created_at"}
              onChange={(e) => handleSortChange(e.target.value)}
              disabled={isPending}
              className="w-full px-3 py-2 border border-zinc-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
            >
              <option value="created_at">Дата создания ↓</option>
              <option value="last_activity">Последняя активность ↓</option>
              <option value="balance">Баланс ↓</option>
              <option value="lifetime">Пополнено ↓</option>
            </select>
          </div>
        </div>

        {/* Type Filter */}
        <div className="mt-4">
          <label className="block text-xs font-medium text-zinc-600 mb-2">
            Тип кошелька
          </label>
          <div className="flex gap-2">
            <button
              onClick={() => handleTypeChange("citypass")}
              disabled={isPending}
              className={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                currentType === "citypass"
                  ? "bg-blue-600 text-white"
                  : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              } disabled:opacity-50`}
            >
              CityPass
            </button>
            <button
              onClick={() => handleTypeChange("cafe_wallet")}
              disabled={isPending}
              className={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                currentType === "cafe_wallet"
                  ? "bg-green-600 text-white"
                  : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              } disabled:opacity-50`}
            >
              Cafe Wallet
            </button>
          </div>
        </div>

        {/* Results Info */}
        <div className="mt-4 pt-4 border-t border-zinc-200 flex items-center justify-between">
          <div className="text-xs text-zinc-500">
            Найдено кошельков:{" "}
            <span className="font-semibold text-zinc-700">{totalResults}</span>
          </div>
          
          {/* Pagination */}
          <div className="flex items-center gap-2">
            <button
              onClick={() => handlePageChange(currentPage - 1)}
              disabled={currentPage <= 1 || isPending}
              className="px-3 py-1 text-xs font-medium text-zinc-700 border border-zinc-300 rounded hover:bg-zinc-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              ← Назад
            </button>
            <span className="text-xs text-zinc-600">
              Стр. {currentPage}
            </span>
            <button
              onClick={() => handlePageChange(currentPage + 1)}
              disabled={!hasMore || isPending}
              className="px-3 py-1 text-xs font-medium text-zinc-700 border border-zinc-300 rounded hover:bg-zinc-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Вперёд →
            </button>
          </div>
        </div>
      </div>

      {/* Active Filters Display */}
      {hasActiveFilters && (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs text-zinc-500">Активные фильтры:</span>
          {currentSearch && (
            <span className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-700 rounded text-xs font-medium">
              Поиск: &quot;{currentSearch}&quot;
              <button
                onClick={() => {
                  setSearch("");
                  updateFilters({ search: undefined });
                }}
                className="hover:text-blue-900"
              >
                ×
              </button>
            </span>
          )}
          {currentType && (
            <span className="inline-flex items-center gap-1 px-2 py-1 bg-emerald-100 text-emerald-700 rounded text-xs font-medium">
              Тип: {currentType === "citypass" ? "CityPass" : "Cafe Wallet"}
              <button
                onClick={() => updateFilters({ type: undefined })}
                className="hover:text-emerald-900"
              >
                ×
              </button>
            </span>
          )}
          {currentSort && currentSort !== "created_at" && (
            <span className="inline-flex items-center gap-1 px-2 py-1 bg-purple-100 text-purple-700 rounded text-xs font-medium">
              Сортировка: {
                currentSort === "last_activity" ? "По активности" :
                currentSort === "balance" ? "По балансу" :
                currentSort === "lifetime" ? "По пополнениям" : currentSort
              }
              <button
                onClick={() => updateFilters({ sort: "created_at" })}
                className="hover:text-purple-900"
              >
                ×
              </button>
            </span>
          )}
        </div>
      )}
    </div>
  );
}
