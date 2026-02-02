import { createAdminClient } from "../admin";

// Loyalty Levels
export async function getLoyaltyLevels() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("loyalty_levels")
    .select("*")
    .order("level_order");

  if (error) {
    console.error("Error fetching loyalty levels:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function updateLoyaltyLevel(
  levelId: string,
  updates: {
    points_required?: number;
    cashback_percent?: number;
    benefits?: string[];
  }
) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("loyalty_levels")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", levelId)
    .select()
    .single();

  if (error) {
    console.error(`Error updating loyalty level ${levelId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

// Achievements
export async function getAchievements() {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("achievements")
    .select("*")
    .order("points_reward", { ascending: false });

  if (error) {
    console.error("Error fetching achievements:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function createAchievement(achievement: {
  achievement_key: string;
  title: string;
  description: string;
  icon: string;
  points_reward: number;
  achievement_type: string;
  requirement_value?: number;
  is_hidden?: boolean;
}) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("achievements")
    .insert([achievement])
    .select()
    .single();

  if (error) {
    console.error("Error creating achievement:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function updateAchievement(
  achievementId: string,
  updates: {
    title?: string;
    description?: string;
    icon?: string;
    points_reward?: number;
    requirement_value?: number;
    is_hidden?: boolean;
  }
) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("achievements")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", achievementId)
    .select()
    .single();

  if (error) {
    console.error(`Error updating achievement ${achievementId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function deleteAchievement(achievementId: string) {
  const supabase = createAdminClient();
  const { error } = await supabase
    .from("achievements")
    .delete()
    .eq("id", achievementId);

  if (error) {
    console.error(`Error deleting achievement ${achievementId}:`, error);
    return { error: error.message };
  }
  return { error: null };
}

// User Loyalty Stats
export async function getUserLoyaltyStats(userId: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("user_loyalty")
    .select(
      `
      *,
      current_level:loyalty_levels(*)
    `
    )
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    console.error(`Error fetching user loyalty stats for ${userId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

export async function getUserAchievements(userId: string) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("user_achievements")
    .select(
      `
      *,
      achievement:achievements(*)
    `
    )
    .eq("user_id", userId)
    .order("unlocked_at", { ascending: false });

  if (error) {
    console.error(`Error fetching user achievements for ${userId}:`, error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

// Leaderboard
export async function getLeaderboard(limit = 100) {
  const supabase = createAdminClient();
  
  try {
    const { data, error } = await supabase.rpc("get_loyalty_leaderboard", {
      p_limit: limit,
    });

    if (error) {
      console.error("Error fetching leaderboard:", error);
      return { data: null, error: error.message };
    }
    return { data, error: null };
  } catch (err) {
    console.error("Error calling leaderboard RPC:", err);
    return { data: null, error: String(err) };
  }
}

// Loyalty Stats Summary
export async function getLoyaltyStatsSummary() {
  const supabase = createAdminClient();
  
  // Get total users with loyalty
  const { count: totalUsers, error: usersError } = await supabase
    .from("user_loyalty")
    .select("*", { count: "exact", head: true });

  if (usersError) {
    console.error("Error counting users:", usersError);
    return { data: null, error: usersError.message };
  }

  // Get users by level
  const { data: usersByLevel, error: levelError } = await supabase
    .from("user_loyalty")
    .select("current_level_id, loyalty_levels(level_name)");

  if (levelError) {
    console.error("Error fetching users by level:", levelError);
    return { data: null, error: levelError.message };
  }

  // Count achievements unlocked
  const { count: totalAchievements, error: achievementsError } = await supabase
    .from("user_achievements")
    .select("*", { count: "exact", head: true });

  if (achievementsError) {
    console.error("Error counting achievements:", achievementsError);
    return { data: null, error: achievementsError.message };
  }

  // Calculate level distribution
  const levelDistribution: Record<string, number> = {};
  usersByLevel?.forEach((user: any) => {
    const levelName = user.loyalty_levels?.level_name || "Unknown";
    levelDistribution[levelName] = (levelDistribution[levelName] || 0) + 1;
  });

  return {
    data: {
      totalUsers: totalUsers || 0,
      totalAchievementsUnlocked: totalAchievements || 0,
      levelDistribution,
    },
    error: null,
  };
}

// Points History
export async function getRecentPointsActivity(limit = 50) {
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("loyalty_points_history")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("Error fetching points activity:", error);
    return { data: null, error: error.message };
  }
  return { data, error: null };
}

// Admin Actions
export async function awardBonusPoints(
  userId: string,
  points: number,
  notes: string
) {
  const supabase = createAdminClient();
  
  try {
    const { data, error } = await supabase.rpc("award_loyalty_points", {
      p_user_id: userId,
      p_points: points,
      p_reason: "admin_adjustment",
      p_notes: notes,
    });

    if (error) {
      console.error("Error awarding bonus points:", error);
      return { data: null, error: error.message };
    }
    return { data, error: null };
  } catch (err) {
    console.error("Error calling award_loyalty_points RPC:", err);
    return { data: null, error: String(err) };
  }
}
