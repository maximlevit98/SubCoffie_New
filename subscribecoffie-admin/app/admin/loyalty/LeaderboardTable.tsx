"use client";

type LeaderboardEntry = {
  rank: number;
  user_id: string;
  total_points: number;
  level_name: string;
  lifetime_orders: number;
};

export default function LeaderboardTable({
  entries,
}: {
  entries: LeaderboardEntry[];
}) {
  const getRankIcon = (rank: number) => {
    if (rank === 1) return "🥇";
    if (rank === 2) return "🥈";
    if (rank === 3) return "🥉";
    return `#${rank}`;
  };

  const getLevelColor = (levelName: string) => {
    const colors: Record<string, string> = {
      Bronze: "text-orange-600 bg-orange-100",
      Silver: "text-zinc-600 bg-zinc-100",
      Gold: "text-yellow-600 bg-yellow-100",
      Platinum: "text-purple-600 bg-purple-100",
    };
    return colors[levelName] || "text-zinc-600 bg-zinc-100";
  };

  return (
    <div className="overflow-hidden rounded-lg border border-zinc-200 bg-white">
      <table className="min-w-full divide-y divide-zinc-200">
        <thead className="bg-zinc-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
              Rank
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
              User ID
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
              Level
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
              Points
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
              Orders
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-zinc-200 bg-white">
          {entries.map((entry) => (
            <tr
              key={entry.user_id}
              className={`hover:bg-zinc-50 ${
                entry.rank <= 3 ? "bg-yellow-50/30" : ""
              }`}
            >
              <td className="whitespace-nowrap px-6 py-4">
                <div className="flex items-center">
                  <span className="text-lg font-semibold">
                    {getRankIcon(entry.rank)}
                  </span>
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="font-mono text-xs text-zinc-600">
                  {entry.user_id.slice(0, 8)}...
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span
                  className={`rounded-full px-2.5 py-1 text-xs font-medium ${getLevelColor(
                    entry.level_name
                  )}`}
                >
                  {entry.level_name}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="flex items-center text-sm font-semibold text-zinc-900">
                  <span className="mr-1">⭐</span>
                  {entry.total_points.toLocaleString()}
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-sm text-zinc-500">
                {entry.lifetime_orders.toLocaleString()}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
