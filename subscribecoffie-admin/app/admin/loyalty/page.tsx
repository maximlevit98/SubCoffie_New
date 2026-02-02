import {
  getLoyaltyLevels,
  getAchievements,
  getLoyaltyStatsSummary,
  getLeaderboard,
} from "../../../lib/supabase/queries/loyalty";
import LoyaltyLevelCard from "./LoyaltyLevelCard";
import AchievementsTable from "./AchievementsTable";
import LeaderboardTable from "./LeaderboardTable";

export default async function LoyaltyPage() {
  const [levelsResult, achievementsResult, statsResult, leaderboardResult] =
    await Promise.all([
      getLoyaltyLevels(),
      getAchievements(),
      getLoyaltyStatsSummary(),
      getLeaderboard(20),
    ]);

  if (levelsResult.error || achievementsResult.error || statsResult.error) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Loyalty Program Management</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Error loading loyalty data:{" "}
          {levelsResult.error || achievementsResult.error || statsResult.error}
        </p>
      </section>
    );
  }

  const levels = levelsResult.data || [];
  const achievements = achievementsResult.data || [];
  const stats = statsResult.data || {
    totalUsers: 0,
    totalAchievementsUnlocked: 0,
    levelDistribution: {},
  };
  const leaderboard = leaderboardResult.data || [];

  return (
    <section className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">Loyalty Program Management</h2>
          <p className="mt-1 text-sm text-zinc-600">
            Manage loyalty levels, achievements, and view program statistics
          </p>
        </div>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <div className="text-sm font-medium text-zinc-500">Total Users</div>
          <div className="mt-2 text-3xl font-bold text-zinc-900">
            {stats.totalUsers.toLocaleString()}
          </div>
          <div className="mt-1 text-xs text-zinc-500">
            Enrolled in loyalty program
          </div>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <div className="text-sm font-medium text-zinc-500">
            Achievements Unlocked
          </div>
          <div className="mt-2 text-3xl font-bold text-zinc-900">
            {stats.totalAchievementsUnlocked.toLocaleString()}
          </div>
          <div className="mt-1 text-xs text-zinc-500">Total across all users</div>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6">
          <div className="text-sm font-medium text-zinc-500">
            Loyalty Levels
          </div>
          <div className="mt-2 text-3xl font-bold text-zinc-900">
            {levels.length}
          </div>
          <div className="mt-1 text-xs text-zinc-500">Active tiers</div>
        </div>
      </div>

      {/* Level Distribution */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 className="mb-4 text-lg font-semibold">Level Distribution</h3>
        <div className="space-y-3">
          {Object.entries(stats.levelDistribution).map(([level, count]) => {
            const percentage =
              stats.totalUsers > 0
                ? ((count as number) / stats.totalUsers) * 100
                : 0;
            return (
              <div key={level}>
                <div className="mb-1 flex items-center justify-between text-sm">
                  <span className="font-medium">{level}</span>
                  <span className="text-zinc-600">
                    {count} users ({percentage.toFixed(1)}%)
                  </span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-zinc-100">
                  <div
                    className="h-full bg-gradient-to-r from-blue-500 to-purple-500"
                    style={{ width: `${percentage}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Loyalty Levels */}
      <div>
        <h3 className="mb-4 text-xl font-semibold">Loyalty Levels</h3>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-4">
          {levels.map((level) => (
            <LoyaltyLevelCard key={level.id} level={level} />
          ))}
        </div>
      </div>

      {/* Leaderboard */}
      {leaderboard.length > 0 && (
        <div>
          <h3 className="mb-4 text-xl font-semibold">Leaderboard (Top 20)</h3>
          <LeaderboardTable entries={leaderboard} />
        </div>
      )}

      {/* Achievements */}
      <div>
        <h3 className="mb-4 text-xl font-semibold">
          Achievements ({achievements.length})
        </h3>
        <AchievementsTable achievements={achievements} />
      </div>
    </section>
  );
}
