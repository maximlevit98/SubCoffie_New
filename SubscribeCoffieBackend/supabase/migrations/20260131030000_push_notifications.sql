-- Migration: Push Notifications Infrastructure
-- Description: Создает таблицу для device tokens и триггеры для отправки уведомлений

-- ============================================================================
-- 1. Таблица для хранения device tokens
-- ============================================================================

create table if not exists public.push_tokens (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  device_token text not null unique,
  platform text not null check (platform in ('ios', 'android')),
  app_version text,
  device_model text,
  is_active boolean default true,
  created_at timestamptz default now(),
  last_used_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_push_tokens_user_id on public.push_tokens(user_id);
create index if not exists idx_push_tokens_active on public.push_tokens(is_active) where is_active = true;

comment on table public.push_tokens is 'Device tokens для push-уведомлений';

-- ============================================================================
-- 2. RPC функции для управления tokens
-- ============================================================================

-- Регистрация/обновление device token
create or replace function register_push_token(
  device_token_param text,
  platform_param text,
  app_version_param text default null,
  device_model_param text default null
)
returns uuid
security definer
language plpgsql
as $$
declare
  token_id uuid;
  current_user_id uuid;
begin
  -- Получаем ID текущего пользователя
  current_user_id := auth.uid();
  
  if current_user_id is null then
    raise exception 'User not authenticated';
  end if;
  
  -- Проверяем валидность platform
  if platform_param not in ('ios', 'android') then
    raise exception 'Invalid platform: %', platform_param;
  end if;
  
  -- Вставляем или обновляем token
  insert into public.push_tokens (
    user_id,
    device_token,
    platform,
    app_version,
    device_model,
    is_active,
    last_used_at
  )
  values (
    current_user_id,
    device_token_param,
    platform_param,
    app_version_param,
    device_model_param,
    true,
    now()
  )
  on conflict (device_token) 
  do update set
    user_id = current_user_id,
    is_active = true,
    app_version = coalesce(app_version_param, public.push_tokens.app_version),
    device_model = coalesce(device_model_param, public.push_tokens.device_model),
    last_used_at = now(),
    updated_at = now()
  returning id into token_id;
  
  return token_id;
end;
$$;

comment on function register_push_token is 'Регистрирует или обновляет device token';

-- Деактивация token
create or replace function deactivate_push_token(device_token_param text)
returns boolean
security definer
language plpgsql
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  
  if current_user_id is null then
    raise exception 'User not authenticated';
  end if;
  
  update public.push_tokens
  set is_active = false, updated_at = now()
  where device_token = device_token_param
  and user_id = current_user_id;
  
  return found;
end;
$$;

comment on function deactivate_push_token is 'Деактивирует device token';

-- Получение активных tokens для пользователя
create or replace function get_user_push_tokens(user_id_param uuid)
returns table (
  id uuid,
  device_token text,
  platform text,
  is_active boolean,
  created_at timestamptz
)
security definer
language plpgsql
as $$
begin
  return query
  select 
    pt.id,
    pt.device_token,
    pt.platform,
    pt.is_active,
    pt.created_at
  from public.push_tokens pt
  where pt.user_id = user_id_param
  and pt.is_active = true
  order by pt.created_at desc;
end;
$$;

comment on function get_user_push_tokens is 'Получает активные push tokens пользователя';

-- ============================================================================
-- 3. Таблица для логирования отправленных уведомлений
-- ============================================================================

create table if not exists public.push_notifications_log (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  token_id uuid references public.push_tokens(id) on delete set null,
  order_id uuid references public.orders_core(id) on delete set null,
  notification_type text not null,
  title text,
  body text,
  payload jsonb,
  status text default 'pending' check (status in ('pending', 'sent', 'failed')),
  error_message text,
  sent_at timestamptz,
  created_at timestamptz default now()
);

create index if not exists idx_push_log_user_id on public.push_notifications_log(user_id);
create index if not exists idx_push_log_order_id on public.push_notifications_log(order_id);
create index if not exists idx_push_log_status on public.push_notifications_log(status);

comment on table public.push_notifications_log is 'Лог отправленных push-уведомлений';

-- ============================================================================
-- 4. Функция для создания уведомления о смене статуса заказа
-- ============================================================================

create or replace function notify_order_status_change()
returns trigger
language plpgsql
security definer
as $$
declare
  user_tokens record;
  notification_title text;
  notification_body text;
begin
  -- Определяем текст уведомления based on new status
  case NEW.status
    when 'paid' then
      notification_title := 'Заказ оплачен';
      notification_body := 'Ваш заказ принят и оплачен';
    when 'preparing' then
      notification_title := 'Заказ готовится';
      notification_body := 'Ваш заказ начали готовить';
    when 'ready' then
      notification_title := 'Заказ готов!';
      notification_body := 'Ваш заказ готов к выдаче';
    when 'issued' then
      notification_title := 'Заказ выдан';
      notification_body := 'Приятного аппетита!';
    when 'cancelled' then
      notification_title := 'Заказ отменён';
      notification_body := 'Ваш заказ был отменён';
    else
      return NEW; -- Не отправляем уведомление для других статусов
  end case;
  
  -- Находим пользователя по телефону (временное решение до полной авторизации)
  -- В продакшене здесь должен быть NEW.user_id
  for user_tokens in 
    select pt.id, pt.user_id, pt.device_token, pt.platform
    from public.push_tokens pt
    where pt.is_active = true
    -- TODO: связать orders с auth.users через user_id
    limit 10 -- защита от спама
  loop
    -- Создаем запись в логе (Edge Function обработает их асинхронно)
    insert into public.push_notifications_log (
      user_id,
      token_id,
      order_id,
      notification_type,
      title,
      body,
      payload,
      status
    )
    values (
      user_tokens.user_id,
      user_tokens.id,
      NEW.id,
      'order_status_change',
      notification_title,
      notification_body,
      jsonb_build_object(
        'order_id', NEW.id,
        'status', NEW.status,
        'cafe_id', NEW.cafe_id
      ),
      'pending'
    );
  end loop;
  
  return NEW;
end;
$$;

comment on function notify_order_status_change is 'Создает записи уведомлений при изменении статуса заказа';

-- Создаем триггер (только если не существует)
do $$
begin
  if not exists (
    select 1 from pg_trigger 
    where tgname = 'trigger_notify_order_status_change'
  ) then
    create trigger trigger_notify_order_status_change
      after update of status on public.orders_core
      for each row
      when (OLD.status is distinct from NEW.status)
      execute function notify_order_status_change();
  end if;
end
$$;

-- ============================================================================
-- 5. RLS Policies
-- ============================================================================

alter table public.push_tokens enable row level security;
alter table public.push_notifications_log enable row level security;

-- Пользователи могут читать и управлять только своими tokens
create policy "Users can read own tokens"
  on public.push_tokens for select
  using (auth.uid() = user_id);

create policy "Users can insert own tokens"
  on public.push_tokens for insert
  with check (auth.uid() = user_id);

create policy "Users can update own tokens"
  on public.push_tokens for update
  using (auth.uid() = user_id);

-- Пользователи могут читать свои уведомления
create policy "Users can read own notifications"
  on public.push_notifications_log for select
  using (auth.uid() = user_id);

-- Админы могут читать все
create policy "Admins can read all notifications"
  on public.push_notifications_log for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================================================
-- Grant permissions
-- ============================================================================

grant select, insert, update on public.push_tokens to authenticated;
grant select on public.push_notifications_log to authenticated;
grant execute on function register_push_token to authenticated;
grant execute on function deactivate_push_token to authenticated;
grant execute on function get_user_push_tokens to authenticated;
