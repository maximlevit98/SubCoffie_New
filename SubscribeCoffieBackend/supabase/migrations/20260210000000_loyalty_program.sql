-- Migration: Loyalty Program & Gamification System
-- Description: Complete loyalty program with levels, achievements, points, and streaks
-- Date: 2026-02-10
-- Reference: LOYALTY_PROGRAM_IMPLEMENTATION.md

-- ============================================================================
-- 1. Create loyalty_levels table (Bronze, Silver, Gold, Platinum)
-- ============================================================================

create table if not exists public.loyalty_levels (
  id uuid primary key default gen_random_uuid(),
  level_name text unique not null check (level_name in ('Bronze', 'Silver', 'Gold', 'Platinum')),
  level_order int unique not null check (level_order between 1 and 4),
  points_required int not null check (points_required >= 0),
  cashback_percent decimal(5,2) not null check (cashback_percent >= 0 and cashback_percent <= 100),
  benefits jsonb not null default '[]'::jsonb,
  badge_color text not null default '#CD7F32',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

comment on table public.loyalty_levels is 'Loyalty program levels with progressive benefits';
comment on column public.loyalty_levels.benefits is 'Array of benefit strings displayed to users';
comment on column public.loyalty_levels.badge_color is 'Hex color code for UI display';

-- Enable RLS
alter table public.loyalty_levels enable row level security;

-- Policies: Everyone can view levels
create policy "Public can view loyalty levels"
  on public.loyalty_levels for select
  using (true);

create policy "Admin can manage loyalty levels"
  on public.loyalty_levels for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Insert default levels
insert into public.loyalty_levels (level_name, level_order, points_required, cashback_percent, benefits, badge_color)
values
  ('Bronze', 1, 0, 2.00, '["Welcome bonus", "Birthday surprise"]'::jsonb, '#CD7F32'),
  ('Silver', 2, 500, 5.00, '["Priority support", "Early access to new items"]'::jsonb, '#C0C0C0'),
  ('Gold', 3, 1500, 10.00, '["Free delivery (orders >500₽)", "Exclusive menu items", "Priority queue"]'::jsonb, '#FFD700'),
  ('Platinum', 4, 5000, 15.00, '["Free delivery (all orders)", "VIP support", "Early access to events", "Personal manager"]'::jsonb, '#E5E4E2')
on conflict (level_name) do nothing;

-- ============================================================================
-- 2. Create user_loyalty table (user progress)
-- ============================================================================

create table if not exists public.user_loyalty (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique not null references auth.users(id) on delete cascade,
  current_level_id uuid not null references public.loyalty_levels(id),
  total_points int not null default 0 check (total_points >= 0),
  points_to_next_level int,
  lifetime_orders int not null default 0 check (lifetime_orders >= 0),
  lifetime_spend_credits int not null default 0 check (lifetime_spend_credits >= 0),
  current_streak_days int not null default 0 check (current_streak_days >= 0),
  longest_streak_days int not null default 0 check (longest_streak_days >= 0),
  last_order_date date,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

comment on table public.user_loyalty is 'User loyalty program status and statistics';
comment on column public.user_loyalty.points_to_next_level is 'Points needed to reach next level (null if max level)';
comment on column public.user_loyalty.current_streak_days is 'Consecutive days with at least one order';
comment on column public.user_loyalty.longest_streak_days is 'Best streak ever achieved';

-- Enable RLS
alter table public.user_loyalty enable row level security;

-- Policies
create policy "Users can view own loyalty status"
  on public.user_loyalty for select
  using (auth.uid() = user_id);

create policy "Admin can view all loyalty status"
  on public.user_loyalty for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "System can manage loyalty"
  on public.user_loyalty for all
  using (true); -- Will be called by SECURITY DEFINER functions

-- Indexes
create index if not exists user_loyalty_user_id_idx on public.user_loyalty(user_id);
create index if not exists user_loyalty_total_points_idx on public.user_loyalty(total_points desc);
create index if not exists user_loyalty_current_level_idx on public.user_loyalty(current_level_id);

-- ============================================================================
-- 3. Create achievements table
-- ============================================================================

create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  achievement_key text unique not null,
  title text not null,
  description text not null,
  icon text not null default '🏆',
  points_reward int not null check (points_reward > 0),
  achievement_type text not null check (achievement_type in ('order_count', 'cafe_count', 'spend', 'streak', 'special')),
  requirement_value int, -- For order_count, cafe_count, spend, streak
  is_hidden boolean not null default false,
  created_at timestamp with time zone default now()
);

comment on table public.achievements is 'Available achievements users can unlock';
comment on column public.achievements.achievement_key is 'Unique identifier for programmatic use';
comment on column public.achievements.achievement_type is 'Type of achievement: order_count, cafe_count, spend, streak, special';
comment on column public.achievements.requirement_value is 'Threshold to unlock (e.g., 10 for "10 orders")';
comment on column public.achievements.is_hidden is 'Whether to show before unlocking (for surprise achievements)';

-- Enable RLS
alter table public.achievements enable row level security;

-- Policies: Everyone can view visible achievements
create policy "Public can view non-hidden achievements"
  on public.achievements for select
  using (is_hidden = false or exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ));

create policy "Admin can manage achievements"
  on public.achievements for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Insert default achievements
insert into public.achievements (achievement_key, title, description, icon, points_reward, achievement_type, requirement_value, is_hidden)
values
  -- Order milestones
  ('first_order', 'First Order', 'Made your first order', '☕', 50, 'order_count', 1, false),
  ('coffee_lover', 'Coffee Lover', 'Completed 5 orders', '☕☕', 100, 'order_count', 5, false),
  ('regular_customer', 'Regular Customer', 'Completed 10 orders', '☕☕☕', 200, 'order_count', 10, false),
  ('coffee_addict', 'Coffee Addict', 'Completed 50 orders', '🏆', 500, 'order_count', 50, false),
  ('coffee_master', 'Coffee Master', 'Completed 100 orders', '👑', 1000, 'order_count', 100, false),
  
  -- Exploration
  ('cafe_explorer', 'Cafe Explorer', 'Visited 5 different cafes', '🗺️', 150, 'cafe_count', 5, false),
  ('cafe_connoisseur', 'Cafe Connoisseur', 'Visited 10 different cafes', '🌟', 300, 'cafe_count', 10, false),
  
  -- Spending
  ('big_spender', 'Big Spender', 'Spent 10,000 credits total', '💰', 400, 'spend', 10000, false),
  
  -- Streaks
  ('week_warrior', 'Week Warrior', 'Ordered 7 days in a row', '🔥', 250, 'streak', 7, false),
  ('monthly_champion', 'Monthly Champion', 'Ordered 30 days in a row', '🔥🔥', 1000, 'streak', 30, false),
  
  -- Special
  ('early_adopter', 'Early Adopter', 'One of the first 100 users', '🚀', 500, 'special', null, true),
  ('night_owl', 'Night Owl', 'Ordered after 10 PM', '🦉', 100, 'special', null, false),
  ('morning_person', 'Morning Person', 'Ordered before 7 AM', '🌅', 100, 'special', null, false)
on conflict (achievement_key) do nothing;

-- ============================================================================
-- 4. Create user_achievements table (unlocked achievements)
-- ============================================================================

create table if not exists public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id uuid not null references public.achievements(id) on delete cascade,
  unlocked_at timestamp with time zone default now(),
  notified boolean default false,
  unique(user_id, achievement_id)
);

comment on table public.user_achievements is 'Achievements unlocked by users';
comment on column public.user_achievements.notified is 'Whether user was notified about unlock';

-- Enable RLS
alter table public.user_achievements enable row level security;

-- Policies
create policy "Users can view own achievements"
  on public.user_achievements for select
  using (auth.uid() = user_id);

create policy "Admin can view all achievements"
  on public.user_achievements for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "System can manage user achievements"
  on public.user_achievements for all
  using (true); -- Will be called by SECURITY DEFINER functions

-- Indexes
create index if not exists user_achievements_user_id_idx on public.user_achievements(user_id);
create index if not exists user_achievements_achievement_id_idx on public.user_achievements(achievement_id);

-- ============================================================================
-- 5. Create loyalty_points_history table (audit trail)
-- ============================================================================

create table if not exists public.loyalty_points_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  points_change int not null, -- Positive or negative
  reason text not null check (reason in ('order_completed', 'achievement_unlocked', 'level_upgrade', 'admin_adjustment', 'bonus')),
  order_id uuid references public.orders_core(id) on delete set null,
  achievement_id uuid references public.achievements(id) on delete set null,
  notes text,
  created_at timestamp with time zone default now()
);

comment on table public.loyalty_points_history is 'Audit trail of all loyalty points changes';
comment on column public.loyalty_points_history.points_change is 'Points added (positive) or removed (negative)';
comment on column public.loyalty_points_history.reason is 'Why points changed';

-- Enable RLS
alter table public.loyalty_points_history enable row level security;

-- Policies
create policy "Users can view own points history"
  on public.loyalty_points_history for select
  using (auth.uid() = user_id);

create policy "Admin can view all points history"
  on public.loyalty_points_history for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "System can insert points history"
  on public.loyalty_points_history for insert
  with check (true); -- Will be called by SECURITY DEFINER functions

-- Indexes
create index if not exists loyalty_points_history_user_id_idx on public.loyalty_points_history(user_id);
create index if not exists loyalty_points_history_created_at_idx on public.loyalty_points_history(created_at desc);

-- ============================================================================
-- 6. RPC: Initialize user loyalty (called for new users)
-- ============================================================================

create or replace function public.initialize_user_loyalty(p_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_bronze_level_id uuid;
  v_existing_loyalty uuid;
begin
  -- Check if already initialized
  select id into v_existing_loyalty
  from public.user_loyalty
  where user_id = p_user_id;
  
  if v_existing_loyalty is not null then
    return jsonb_build_object(
      'success', true,
      'message', 'Loyalty already initialized',
      'loyalty_id', v_existing_loyalty
    );
  end if;
  
  -- Get Bronze level ID
  select id into v_bronze_level_id
  from public.loyalty_levels
  where level_name = 'Bronze';
  
  if v_bronze_level_id is null then
    raise exception 'Bronze level not found. Run loyalty migration first.';
  end if;
  
  -- Create user loyalty record
  insert into public.user_loyalty (user_id, current_level_id, total_points, points_to_next_level)
  values (p_user_id, v_bronze_level_id, 0, 500) -- 500 points to Silver
  returning id into v_existing_loyalty;
  
  return jsonb_build_object(
    'success', true,
    'message', 'Loyalty initialized',
    'loyalty_id', v_existing_loyalty
  );
end;
$$;

comment on function public.initialize_user_loyalty is 'Initialize loyalty program for new user (Bronze level, 0 points)';

grant execute on function public.initialize_user_loyalty(uuid) to authenticated;

-- ============================================================================
-- 7. RPC: Calculate loyalty points from order amount
-- ============================================================================

create or replace function public.calculate_loyalty_points(p_order_amount int)
returns int
language plpgsql
immutable
as $$
begin
  -- Formula: 1 point per 10 credits, minimum 1 point
  return greatest(1, p_order_amount / 10);
end;
$$;

comment on function public.calculate_loyalty_points is 'Calculate loyalty points from order amount (1 point per 10 credits, min 1)';

-- ============================================================================
-- 8. RPC: Award loyalty points (internal)
-- ============================================================================

create or replace function public.award_loyalty_points(
  p_user_id uuid,
  p_points int,
  p_reason text,
  p_order_id uuid default null,
  p_achievement_id uuid default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_new_total int;
begin
  -- Update user total points
  update public.user_loyalty
  set
    total_points = total_points + p_points,
    updated_at = now()
  where user_id = p_user_id
  returning total_points into v_new_total;
  
  -- Create history entry
  insert into public.loyalty_points_history (user_id, points_change, reason, order_id, achievement_id, notes)
  values (p_user_id, p_points, p_reason, p_order_id, p_achievement_id, p_notes);
  
  -- Check for level upgrade
  perform public.check_and_upgrade_loyalty_level(p_user_id);
  
  return jsonb_build_object(
    'success', true,
    'points_awarded', p_points,
    'new_total', v_new_total
  );
end;
$$;

comment on function public.award_loyalty_points is 'Award points to user and create history entry. Triggers level upgrade check.';

-- ============================================================================
-- 9. RPC: Check and upgrade loyalty level
-- ============================================================================

create or replace function public.check_and_upgrade_loyalty_level(p_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_current_points int;
  v_current_level_order int;
  v_new_level record;
  v_upgraded boolean := false;
  v_bonus_points int;
begin
  -- Get user's current points and level
  select ul.total_points, ll.level_order
  into v_current_points, v_current_level_order
  from public.user_loyalty ul
  join public.loyalty_levels ll on ul.current_level_id = ll.id
  where ul.user_id = p_user_id;
  
  -- Find highest eligible level
  select *
  into v_new_level
  from public.loyalty_levels
  where points_required <= v_current_points
    and level_order > v_current_level_order
  order by level_order desc
  limit 1;
  
  -- Upgrade if eligible
  if v_new_level.id is not null then
    v_upgraded := true;
    v_bonus_points := 100 * v_new_level.level_order; -- Bonus: 100 × level_order
    
    -- Update user level
    update public.user_loyalty
    set
      current_level_id = v_new_level.id,
      total_points = total_points + v_bonus_points,
      updated_at = now()
    where user_id = p_user_id;
    
    -- Award bonus points for level up
    insert into public.loyalty_points_history (user_id, points_change, reason, notes)
    values (
      p_user_id,
      v_bonus_points,
      'level_upgrade',
      format('Upgraded to %s level!', v_new_level.level_name)
    );
  end if;
  
  -- Update points_to_next_level
  update public.user_loyalty ul
  set points_to_next_level = (
    select ll.points_required - ul.total_points
    from public.loyalty_levels ll
    where ll.level_order = (
      select level_order + 1
      from public.loyalty_levels
      where id = ul.current_level_id
    )
    limit 1
  )
  where ul.user_id = p_user_id;
  
  return jsonb_build_object(
    'upgraded', v_upgraded,
    'new_level', v_new_level.level_name,
    'bonus_points', v_bonus_points
  );
end;
$$;

comment on function public.check_and_upgrade_loyalty_level is 'Check if user qualifies for higher level and upgrade if so';

-- ============================================================================
-- 10. RPC: Check and unlock achievements
-- ============================================================================

create or replace function public.check_and_unlock_achievements(p_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_loyalty record;
  v_unlocked_count int := 0;
  v_achievement record;
  v_unique_cafes_count int;
  v_achievements_unlocked jsonb := '[]'::jsonb;
begin
  -- Get user loyalty stats
  select * into v_loyalty
  from public.user_loyalty
  where user_id = p_user_id;
  
  if v_loyalty.id is null then
    raise exception 'User loyalty not initialized';
  end if;
  
  -- Count unique cafes visited
  select count(distinct cafe_id) into v_unique_cafes_count
  from public.orders_core
  where user_id = p_user_id and status = 'issued';
  
  -- Check each achievement type
  for v_achievement in
    select a.*
    from public.achievements a
    where not exists (
      select 1 from public.user_achievements ua
      where ua.user_id = p_user_id and ua.achievement_id = a.id
    )
  loop
    declare
      v_unlocked boolean := false;
    begin
      case v_achievement.achievement_type
        when 'order_count' then
          v_unlocked := v_loyalty.lifetime_orders >= v_achievement.requirement_value;
        when 'cafe_count' then
          v_unlocked := v_unique_cafes_count >= v_achievement.requirement_value;
        when 'spend' then
          v_unlocked := v_loyalty.lifetime_spend_credits >= v_achievement.requirement_value;
        when 'streak' then
          v_unlocked := v_loyalty.current_streak_days >= v_achievement.requirement_value;
        when 'special' then
          -- Special achievements handled by specific logic (early_adopter, night_owl, etc.)
          v_unlocked := false;
      end case;
      
      if v_unlocked then
        -- Unlock achievement
        insert into public.user_achievements (user_id, achievement_id)
        values (p_user_id, v_achievement.id);
        
        -- Award points
        perform public.award_loyalty_points(
          p_user_id,
          v_achievement.points_reward,
          'achievement_unlocked',
          null,
          v_achievement.id,
          v_achievement.title
        );
        
        v_unlocked_count := v_unlocked_count + 1;
        
        v_achievements_unlocked := v_achievements_unlocked || jsonb_build_object(
          'id', v_achievement.id,
          'title', v_achievement.title,
          'points', v_achievement.points_reward
        );
      end if;
    end;
  end loop;
  
  return jsonb_build_object(
    'unlocked_count', v_unlocked_count,
    'achievements', v_achievements_unlocked
  );
end;
$$;

comment on function public.check_and_unlock_achievements is 'Check all achievement criteria and unlock eligible ones';

grant execute on function public.check_and_unlock_achievements(uuid) to authenticated;

-- ============================================================================
-- 11. RPC: Get loyalty dashboard (complete data)
-- ============================================================================

create or replace function public.get_loyalty_dashboard(p_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_loyalty jsonb;
  v_current_level jsonb;
  v_unlocked_achievements jsonb;
  v_locked_achievements jsonb;
  v_recent_points_history jsonb;
begin
  -- Check authorization
  if auth.uid() != p_user_id and not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Unauthorized';
  end if;
  
  -- Get user loyalty status
  select to_jsonb(ul.*)
  into v_user_loyalty
  from public.user_loyalty ul
  where ul.user_id = p_user_id;
  
  if v_user_loyalty is null then
    raise exception 'User loyalty not initialized';
  end if;
  
  -- Get current level details
  select to_jsonb(ll.*)
  into v_current_level
  from public.loyalty_levels ll
  where ll.id = (v_user_loyalty->>'current_level_id')::uuid;
  
  -- Get unlocked achievements with unlock dates
  select jsonb_agg(
    jsonb_build_object(
      'achievement', to_jsonb(a.*),
      'unlocked_at', ua.unlocked_at
    )
    order by ua.unlocked_at desc
  )
  into v_unlocked_achievements
  from public.user_achievements ua
  join public.achievements a on ua.achievement_id = a.id
  where ua.user_id = p_user_id;
  
  -- Get locked achievements (visible ones)
  select jsonb_agg(to_jsonb(a.*))
  into v_locked_achievements
  from public.achievements a
  where a.is_hidden = false
    and not exists (
      select 1 from public.user_achievements ua
      where ua.user_id = p_user_id and ua.achievement_id = a.id
    );
  
  -- Get recent points history (last 20)
  select jsonb_agg(to_jsonb(lph.*) order by lph.created_at desc)
  into v_recent_points_history
  from (
    select * from public.loyalty_points_history
    where user_id = p_user_id
    order by created_at desc
    limit 20
  ) lph;
  
  return jsonb_build_object(
    'user_loyalty', v_user_loyalty,
    'current_level', v_current_level,
    'unlocked_achievements', coalesce(v_unlocked_achievements, '[]'::jsonb),
    'locked_achievements', coalesce(v_locked_achievements, '[]'::jsonb),
    'recent_points_history', coalesce(v_recent_points_history, '[]'::jsonb)
  );
end;
$$;

comment on function public.get_loyalty_dashboard is 'Get complete loyalty dashboard data for user';

grant execute on function public.get_loyalty_dashboard(uuid) to authenticated;

-- ============================================================================
-- 12. RPC: Get loyalty leaderboard
-- ============================================================================

create or replace function public.get_loyalty_leaderboard(p_limit int default 100)
returns table(
  rank bigint,
  user_id uuid,
  total_points int,
  level_name text,
  lifetime_orders int
)
language plpgsql
security definer
as $$
begin
  return query
  select
    row_number() over (order by ul.total_points desc) as rank,
    ul.user_id,
    ul.total_points,
    ll.level_name,
    ul.lifetime_orders
  from public.user_loyalty ul
  join public.loyalty_levels ll on ul.current_level_id = ll.id
  order by ul.total_points desc
  limit p_limit;
end;
$$;

comment on function public.get_loyalty_leaderboard is 'Get top users by loyalty points';

grant execute on function public.get_loyalty_leaderboard(int) to authenticated;

-- ============================================================================
-- 13. Trigger: Award loyalty points on order issued
-- ============================================================================

create or replace function trigger_order_issued_loyalty()
returns trigger
language plpgsql
security definer
as $$
declare
  v_points int;
  v_order_hour int;
  v_order_date date;
  v_last_order_date date;
  v_current_streak int;
  v_longest_streak int;
begin
  -- Only process when order becomes 'issued'
  if NEW.status = 'issued' and (OLD is null or OLD.status != 'issued') then
    
    -- Calculate points for this order
    v_points := public.calculate_loyalty_points(NEW.paid_credits);
    
    -- Award points
    perform public.award_loyalty_points(
      NEW.user_id,
      v_points,
      'order_completed',
      NEW.id,
      null,
      format('Order #%s: %s credits', NEW.id, NEW.paid_credits)
    );
    
    -- Update lifetime stats
    v_order_date := NEW.created_at::date;
    
    select last_order_date, current_streak_days, longest_streak_days
    into v_last_order_date, v_current_streak, v_longest_streak
    from public.user_loyalty
    where user_id = NEW.user_id;
    
    -- Calculate streak
    if v_last_order_date is null then
      -- First order
      v_current_streak := 1;
    elsif v_order_date = v_last_order_date then
      -- Same day, don't change streak
      v_current_streak := v_current_streak;
    elsif v_order_date = v_last_order_date + interval '1 day' then
      -- Next day, increment streak
      v_current_streak := v_current_streak + 1;
    else
      -- Streak broken, reset
      v_current_streak := 1;
    end if;
    
    -- Update longest streak if needed
    v_longest_streak := greatest(v_longest_streak, v_current_streak);
    
    update public.user_loyalty
    set
      lifetime_orders = lifetime_orders + 1,
      lifetime_spend_credits = lifetime_spend_credits + NEW.paid_credits,
      current_streak_days = v_current_streak,
      longest_streak_days = v_longest_streak,
      last_order_date = v_order_date,
      updated_at = now()
    where user_id = NEW.user_id;
    
    -- Check for time-based achievements
    v_order_hour := extract(hour from NEW.created_at);
    
    if v_order_hour >= 22 or v_order_hour <= 23 then
      -- Night Owl (10 PM - 11:59 PM)
      insert into public.user_achievements (user_id, achievement_id)
      select NEW.user_id, a.id
      from public.achievements a
      where a.achievement_key = 'night_owl'
        and not exists (
          select 1 from public.user_achievements ua
          where ua.user_id = NEW.user_id and ua.achievement_id = a.id
        )
      on conflict do nothing;
    elsif v_order_hour >= 0 and v_order_hour < 7 then
      -- Morning Person (12 AM - 6:59 AM)
      insert into public.user_achievements (user_id, achievement_id)
      select NEW.user_id, a.id
      from public.achievements a
      where a.achievement_key = 'morning_person'
        and not exists (
          select 1 from public.user_achievements ua
          where ua.user_id = NEW.user_id and ua.achievement_id = a.id
        )
      on conflict do nothing;
    end if;
    
    -- Check all achievements
    perform public.check_and_unlock_achievements(NEW.user_id);
  end if;
  
  return NEW;
end;
$$;

-- Create trigger on orders_core
drop trigger if exists trigger_order_issued_loyalty on public.orders_core;
create trigger trigger_order_issued_loyalty
  after insert or update on public.orders_core
  for each row
  execute function trigger_order_issued_loyalty();

comment on function trigger_order_issued_loyalty is 'Awards loyalty points and updates stats when order is issued';

-- ============================================================================
-- 14. Admin RPC: Award bonus points
-- ============================================================================

create or replace function public.admin_award_bonus_points(
  p_user_id uuid,
  p_points int,
  p_notes text
)
returns jsonb
language plpgsql
security definer
as $$
begin
  -- Check admin authorization
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Unauthorized: Admin only';
  end if;
  
  -- Award points
  return public.award_loyalty_points(
    p_user_id,
    p_points,
    'admin_adjustment',
    null,
    null,
    p_notes
  );
end;
$$;

comment on function public.admin_award_bonus_points is 'Admin function to award bonus points to users';

grant execute on function public.admin_award_bonus_points(uuid, int, text) to authenticated;

-- ============================================================================
-- 15. Documentation
-- ============================================================================

comment on schema public is 'Public schema with loyalty program tables:
- loyalty_levels: Bronze/Silver/Gold/Platinum with progressive benefits
- user_loyalty: User progress, points, streaks
- achievements: 13 default achievements (orders, exploration, streaks)
- user_achievements: Unlocked achievements per user
- loyalty_points_history: Audit trail of all points changes

RPCs:
- initialize_user_loyalty: Set up new user (Bronze, 0 points)
- get_loyalty_dashboard: Complete dashboard data
- get_loyalty_leaderboard: Top users by points
- check_and_unlock_achievements: Manual achievement check
- admin_award_bonus_points: Admin bonus points

Triggers:
- trigger_order_issued_loyalty: Auto-awards points on order completion

Points Formula:
- 1 point per 10 credits spent (min 1)
- Achievements award bonus points
- Level upgrades award 100 × level_order points

Streaks:
- Daily basis (one order per day)
- Same-day orders don''t extend streak
- Missing a day resets to 1';
