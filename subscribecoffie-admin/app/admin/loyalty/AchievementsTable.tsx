"use client";

import { useState } from "react";

type Achievement = {
  id: string;
  achievement_key: string;
  title: string;
  description: string;
  icon: string;
  points_reward: number;
  achievement_type: string;
  requirement_value: number | null;
  is_hidden: boolean;
  created_at: string;
};

export default function AchievementsTable({
  achievements,
}: {
  achievements: Achievement[];
}) {
  const [filter, setFilter] = useState<string>("all");

  const filteredAchievements =
    filter === "all"
      ? achievements
      : achievements.filter((a) => a.achievement_type === filter);

  const achievementTypes = [
    "all",
    ...Array.from(new Set(achievements.map((a) => a.achievement_type))),
  ];

  return (
    <div className="space-y-4">
      {/* Filter */}
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium text-zinc-700">Filter:</span>
        {achievementTypes.map((type) => (
          <button
            key={type}
            onClick={() => setFilter(type)}
            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
              filter === type
                ? "bg-blue-500 text-white"
                : "bg-zinc-100 text-zinc-600 hover:bg-zinc-200"
            }`}
          >
            {type === "all" ? "All" : type.replace("_", " ")}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="overflow-hidden rounded-lg border border-zinc-200 bg-white">
        <table className="min-w-full divide-y divide-zinc-200">
          <thead className="bg-zinc-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                Achievement
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                Type
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                Requirement
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                Points
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">
                Status
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-200 bg-white">
            {filteredAchievements.map((achievement) => (
              <tr key={achievement.id} className="hover:bg-zinc-50">
                <td className="whitespace-nowrap px-6 py-4">
                  <div className="flex items-center">
                    <span className="mr-3 text-2xl">{achievement.icon}</span>
                    <div>
                      <div className="font-medium text-zinc-900">
                        {achievement.title}
                      </div>
                      <div className="text-sm text-zinc-500">
                        {achievement.description}
                      </div>
                    </div>
                  </div>
                </td>
                <td className="whitespace-nowrap px-6 py-4">
                  <span className="rounded-full bg-blue-100 px-2.5 py-1 text-xs font-medium text-blue-700">
                    {achievement.achievement_type.replace("_", " ")}
                  </span>
                </td>
                <td className="whitespace-nowrap px-6 py-4 text-sm text-zinc-500">
                  {achievement.requirement_value
                    ? achievement.requirement_value.toLocaleString()
                    : "—"}
                </td>
                <td className="whitespace-nowrap px-6 py-4">
                  <span className="flex items-center text-sm font-semibold text-yellow-600">
                    <span className="mr-1">⭐</span>
                    {achievement.points_reward}
                  </span>
                </td>
                <td className="whitespace-nowrap px-6 py-4">
                  {achievement.is_hidden ? (
                    <span className="rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-medium text-zinc-600">
                      Hidden
                    </span>
                  ) : (
                    <span className="rounded-full bg-green-100 px-2.5 py-1 text-xs font-medium text-green-700">
                      Visible
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {filteredAchievements.length === 0 && (
        <div className="rounded-lg border border-zinc-200 bg-white p-8 text-center">
          <p className="text-sm text-zinc-500">
            No achievements found for this filter.
          </p>
        </div>
      )}
    </div>
  );
}
