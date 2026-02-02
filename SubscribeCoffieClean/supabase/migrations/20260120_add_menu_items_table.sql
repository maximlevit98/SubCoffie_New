-- Ensure menu_items exists (idempotent) for REST /menu_items
create table if not exists public.menu_items (
    id uuid primary key default uuid_generate_v4(),
    cafe_id uuid references public.cafes(id) on delete cascade,
    category text not null,
    name text not null,
    description text not null,
    price_credits int not null,
    is_available boolean default true,
    sort_order int default 0,
    created_at timestamptz default now()
);

-- RLS for anon select (if not already present)
alter table public.menu_items enable row level security;
do $$
begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public'
          and tablename = 'menu_items'
          and policyname = 'anon_select_menu_items'
    ) then
        create policy "anon_select_menu_items"
            on public.menu_items for select
            to anon
            using (true);
    end if;
end$$;

-- Seed minimal data if table is empty
insert into public.menu_items (cafe_id, category, name, description, price_credits, sort_order)
select cafes.id, seed.category, seed.name, seed.description, seed.price_credits, seed.sort_order
from public.cafes
cross join (
    values
        ('drinks','Эспрессо','Классический, насыщенный шот',150,1),
        ('drinks','Капучино','Эспрессо, молоко, плотная пена',240,2),
        ('food','Круассан','Сливочное тесто, хрустящая корочка',180,1),
        ('food','Чизкейк','Нежный сырный десерт',320,2),
        ('syrups','Ваниль','Добавка к напитку',40,1),
        ('merch','Кружка','Керамика, 350 мл',550,1)
) as seed(category, name, description, price_credits, sort_order)
where not exists (select 1 from public.menu_items);
