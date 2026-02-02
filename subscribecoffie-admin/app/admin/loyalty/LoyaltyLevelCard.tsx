"use client";

type LoyaltyLevel = {
  id: string;
  level_name: string;
  level_order: number;
  points_required: number;
  cashback_percent: number;
  benefits: string[];
  badge_color: string;
  created_at: string;
};

export default function LoyaltyLevelCard({ level }: { level: LoyaltyLevel }) {
  const icons: Record<number, string> = {
    1: "🥉",
    2: "🥈",
    3: "🥇",
    4: "💎",
  };

  const icon = icons[level.level_order] || "⭐";

  return (
    <div
      className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm transition-shadow hover:shadow-md"
      style={{
        borderColor: level.badge_color + "40",
      }}
    >
      {/* Icon and Name */}
      <div className="mb-4 text-center">
        <div className="mb-2 text-5xl">{icon}</div>
        <h4 className="text-xl font-bold" style={{ color: level.badge_color }}>
          {level.level_name}
        </h4>
        <div className="mt-1 text-sm text-zinc-500">Level {level.level_order}</div>
      </div>

      {/* Points Required */}
      <div className="mb-4 rounded-lg bg-zinc-50 p-3 text-center">
        <div className="text-2xl font-bold text-zinc-900">
          {level.points_required.toLocaleString()}
        </div>
        <div className="text-xs text-zinc-500">Points Required</div>
      </div>

      {/* Cashback */}
      <div className="mb-4 flex items-center justify-between rounded-lg bg-green-50 p-3">
        <span className="text-sm font-medium text-green-700">Cashback</span>
        <span className="text-lg font-bold text-green-700">
          {level.cashback_percent}%
        </span>
      </div>

      {/* Benefits */}
      <div>
        <div className="mb-2 text-xs font-semibold uppercase text-zinc-500">
          Benefits
        </div>
        <ul className="space-y-1.5">
          {level.benefits.slice(0, 3).map((benefit, idx) => (
            <li key={idx} className="flex items-start text-xs text-zinc-600">
              <span className="mr-2 mt-0.5 text-green-500">✓</span>
              <span className="flex-1">{benefit}</span>
            </li>
          ))}
          {level.benefits.length > 3 && (
            <li className="text-xs italic text-zinc-400">
              +{level.benefits.length - 3} more...
            </li>
          )}
        </ul>
      </div>
    </div>
  );
}
