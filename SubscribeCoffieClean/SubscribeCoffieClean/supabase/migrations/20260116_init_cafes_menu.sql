-- Создание таблиц для кофеен и меню
create extension if not exists "uuid-ossp";

create table if not exists public.cafes (
    id uuid primary key,
    name text not null,
    address text not null,
    mode text not null,
    eta_minutes int not null default 0,
    active_orders int not null default 0,
    max_active_orders int not null default 0,
    distance_minutes int not null default 0,
    supports_citypass boolean default false,
    created_at timestamp with time zone default now()
);

create table if not exists public.menu_items (
    id uuid primary key,
    cafe_id uuid references public.cafes(id) on delete cascade,
    category text not null,
    name text not null,
    description text default '',
    price_credits int not null default 0,
    is_available boolean not null default true,
    sort_order int default 0,
    created_at timestamp with time zone default now()
);

-- RLS: разрешаем select для anon (MVP)
alter table public.cafes enable row level security;
alter table public.menu_items enable row level security;

drop policy if exists "anon_select" on public.cafes;
create policy "anon_select" on public.cafes for select using (true);

drop policy if exists "anon_select_menu" on public.menu_items;
create policy "anon_select_menu" on public.menu_items for select using (true);

-- Демо данные (совпадают с моками)
insert into public.cafes (id, name, address, mode, eta_minutes, active_orders, max_active_orders, distance_minutes, supports_citypass)
values
    ('11111111-1111-1111-1111-111111111111', 'Coffee Point ☕️', 'ул. Примерная, 10', 'open', 8, 6, 18, 6, true),
    ('22222222-2222-2222-2222-222222222222', 'Brew Lab', 'пр-т Кофейный, 21', 'busy', 14, 16, 18, 9, true),
    ('33333333-3333-3333-3333-333333333333', 'Roast & Go', 'ул. Центральная, 5', 'paused', 0, 0, 18, 12, false),
    ('44444444-4444-4444-4444-444444444444', 'Morning Cup', 'наб. Уютная, 3', 'open', 10, 18, 18, 15, true),
    ('55555555-5555-5555-5555-555555555555', 'Nordic Beans', 'пл. Севера, 1', 'closed', 0, 0, 18, 22, false)
on conflict (id) do nothing;

-- Меню для Coffee Point (40 позиций: 10/10/10/10)
insert into public.menu_items (id, cafe_id, category, name, description, price_credits, is_available, sort_order)
values
    -- drinks
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Эспрессо', 'Классический, насыщенный шот', 150, true, 1),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Американо', 'Эспрессо + горячая вода', 180, true, 2),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Капучино', 'Эспрессо, молоко, плотная пена', 240, true, 3),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Латте', 'Мягкий кофе с молоком', 260, true, 4),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Флэт уайт', 'Более крепкий и бархатный', 270, true, 5),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Раф ванильный', 'Сливочный, сладкий, ваниль', 320, true, 6),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Матча латте', 'Матча + молоко, бодрит мягко', 310, true, 7),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Какао', 'Тёплый шоколадный напиток', 260, true, 8),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Чай чёрный', 'Классический, крепкий', 160, true, 9),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'drinks', 'Айс-латте', 'Латте со льдом', 290, true, 10),
    -- food
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Круассан классический', 'Сливочное тесто, хрустящая корочка', 180, true, 1),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Круассан миндальный', 'Миндальный крем и лепестки', 220, true, 2),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Синнабон', 'Булочка с корицей и глазурью', 240, true, 3),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Чизкейк Нью-Йорк', 'Нежный сырный десерт', 320, true, 4),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Брауни', 'Шоколадный, влажный', 210, true, 5),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Сэндвич с курицей', 'Курица, соус, салат, хлеб', 360, true, 6),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Сэндвич с лососем', 'Лосось, сливочный сыр, зелень', 420, true, 7),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Овсянка ягодная', 'Овсянка + ягоды + мёд', 280, true, 8),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Йогурт с гранолой', 'Йогурт, гранола, фрукты', 260, true, 9),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'food', 'Маффин шоколадный', 'С кусочками шоколада', 190, true, 10),
    -- syrups
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Ваниль', 'Добавка к напитку (1 порция)', 40, true, 1),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Карамель', 'Добавка к напитку (1 порция)', 40, true, 2),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Лесной орех', 'Добавка к напитку (1 порция)', 40, true, 3),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Шоколад', 'Добавка к напитку (1 порция)', 45, true, 4),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Кокос', 'Добавка к напитку (1 порция)', 45, true, 5),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Мята', 'Добавка к напитку (1 порция)', 45, true, 6),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Корица', 'Добавка к напитку (1 порция)', 35, true, 7),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Имбирь', 'Добавка к напитку (1 порция)', 35, true, 8),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Солёная карамель', 'Добавка к напитку (1 порция)', 50, true, 9),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'syrups', 'Кленовый', 'Добавка к напитку (1 порция)', 50, true, 10),
    -- merch
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Кружка брендированная', 'Керамика, 350 мл', 550, true, 1),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Термокружка', 'Держит тепло 4–6 часов', 890, true, 2),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Футболка Coffee Club', 'Хлопок, унисекс', 990, true, 3),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Худи Coffee Club', 'Плотный материал, oversize', 1790, true, 4),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Кепка с логотипом', 'Регулируемый ремешок', 690, true, 5),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Шоппер', 'Плотная ткань, длинные ручки', 520, true, 6),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Набор стикеров', '10 шт, водостойкие', 190, true, 7),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Пин металлический', 'Эмаль, фирменный дизайн', 240, true, 8),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Дрип-пакеты (10 шт)', 'Кофе для заваривания дома', 760, true, 9),
    (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'merch', 'Зёрна 250 г', 'Фирменная обжарка', 980, true, 10)
on conflict (id) do nothing;
