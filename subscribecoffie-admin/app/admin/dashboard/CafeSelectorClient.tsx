'use client';

import { useRouter } from 'next/navigation';

export function CafeSelectorClient({
  cafes,
  currentCafeId,
}: {
  cafes: any[];
  currentCafeId?: string;
}) {
  const router = useRouter();

  return (
    <div className="flex items-center gap-2">
      <label htmlFor="cafe-select" className="text-sm text-zinc-600">
        Кафе:
      </label>
      <select
        id="cafe-select"
        className="rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        value={currentCafeId || ""}
        onChange={(e) => {
          const value = e.target.value;
          if (value) {
            router.push(`/admin/dashboard?cafe_id=${value}`);
          } else {
            router.push("/admin/dashboard");
          }
        }}
      >
        <option value="">Все кафе</option>
        {cafes.map((cafe) => (
          <option key={cafe.id} value={cafe.id}>
            {cafe.name}
          </option>
        ))}
      </select>
    </div>
  );
}
