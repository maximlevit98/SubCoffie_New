"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState, useTransition } from "react";

type WalletsFiltersProps = {
  currentType?: string;
  currentSearch?: string;
  totalResults: number;
};

export function WalletsFilters({
  currentType,
  currentSearch,
  totalResults,
}: WalletsFiltersProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [isPending, startTransition] = useTransition();
  
  const [search, setSearch] = useState(currentSearch || "");

  const updateFilters = (type?: string, searchValue?: string) => {
    const params = new URLSearchParams(searchParams.toString());
    
    if (type) {
      params.set("type", type);
    } else {
      params.delete("type");
    }
    
    if (searchValue && searchValue.trim()) {
      params.set("search", searchValue.trim());
    } else {
      params.delete("search");
    }
    
    startTransition(() => {
      router.push(`/admin/wallets?${params.toString()}`);
    });
  };

  const handleTypeChange = (type: string) => {
    if (currentType === type) {
      // Deselect if already selected
      updateFilters(undefined, search);
    } else {
      updateFilters(type, search);
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    updateFilters(currentType, search);
  };

  const handleClearAll = () => {
    setSearch("");
    updateFilters(undefined, undefined);
  };

  const hasActiveFilters = currentType || currentSearch;

  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-4">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-zinc-700">
          Фильтры и поиск
        </h3>
        {hasActiveFilters && (
          <button
            onClick={handleClearAll}
            className="text-xs text-zinc-500 hover:text-zinc-700 underline"
          >
            Сбросить всё
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Wallet Type Filter */}
        <div>
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

        {/* Search */}
        <form onSubmit={handleSearchSubmit}>
          <label
            htmlFor="search"
            className="block text-xs font-medium text-zinc-600 mb-2"
          >
            Поиск по пользователю
          </label>
          <div className="flex gap-2">
            <input
              id="search"
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Имя или телефон..."
              className="flex-1 px-3 py-2 border border-zinc-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              disabled={isPending}
            />
            <button
              type="submit"
              disabled={isPending}
              className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isPending ? "..." : "Найти"}
            </button>
          </div>
        </form>
      </div>

      {/* Results count */}
      <div className="mt-3 pt-3 border-t border-zinc-200">
        <p className="text-xs text-zinc-500">
          Найдено пользователей:{" "}
          <span className="font-semibold text-zinc-700">{totalResults}</span>
        </p>
      </div>
    </div>
  );
}
