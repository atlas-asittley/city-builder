-- 0001_initial_schema.sql
-- Initial schema for Multiplayer City Builder v1

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.resource_types (
  key text primary key,
  name text not null,
  category text not null,
  base_value numeric not null default 0,
  is_active boolean not null default true
);

create table if not exists public.building_types (
  key text primary key,
  name text not null,
  category text not null,
  footprint_w integer not null default 1,
  footprint_h integer not null default 1,
  cost_gold integer not null,
  maintenance_gold integer not null default 0,
  required_resource_key text references public.resource_types(key),
  output_resource_key text references public.resource_types(key),
  build_rules jsonb not null default '{}'::jsonb,
  is_active boolean not null default true
);

create table if not exists public.worlds (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  status text not null default 'active',
  width integer not null,
  height integer not null,
  tick_version integer not null default 1,
  created_at timestamptz not null default now(),
  check (status in ('active', 'archived', 'maintenance')),
  check (width > 0),
  check (height > 0)
);

create table if not exists public.player_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  specialization_key text references public.resource_types(key),
  home_world_id uuid references public.worlds(id) on delete set null,
  home_district_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.districts (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  owner_player_id uuid unique references public.player_profiles(id) on delete set null,
  name text,
  origin_x integer not null,
  origin_y integer not null,
  width integer not null,
  height integer not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  check (status in ('active', 'reserved', 'inactive')),
  check (width > 0),
  check (height > 0)
);

create table if not exists public.tiles (
  id bigint generated always as identity primary key,
  world_id uuid not null references public.worlds(id) on delete cascade,
  district_id uuid references public.districts(id) on delete set null,
  x integer not null,
  y integer not null,
  terrain_key text not null,
  resource_key text references public.resource_types(key),
  is_revealed boolean not null default true,
  is_buildable boolean not null default true,
  owner_player_id uuid references public.player_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (world_id, x, y)
);

create table if not exists public.buildings (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  district_id uuid references public.districts(id) on delete set null,
  owner_player_id uuid not null references public.player_profiles(id) on delete cascade,
  building_type_key text not null references public.building_types(key),
  anchor_x integer not null,
  anchor_y integer not null,
  level integer not null default 1,
  status text not null default 'active',
  workers_assigned integer not null default 0,
  production_progress numeric not null default 0,
  last_tick_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('active', 'paused', 'demolished')),
  check (level > 0),
  check (workers_assigned >= 0),
  check (production_progress >= 0)
);

create table if not exists public.player_treasuries (
  player_id uuid primary key references public.player_profiles(id) on delete cascade,
  gold integer not null default 500,
  income_per_tick integer not null default 0,
  expenses_per_tick integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.player_inventories (
  player_id uuid not null references public.player_profiles(id) on delete cascade,
  resource_key text not null references public.resource_types(key),
  amount numeric not null default 0,
  capacity numeric,
  updated_at timestamptz not null default now(),
  primary key (player_id, resource_key),
  check (amount >= 0),
  check (capacity is null or capacity >= 0)
);

create table if not exists public.population_state (
  player_id uuid primary key references public.player_profiles(id) on delete cascade,
  district_id uuid references public.districts(id) on delete cascade,
  total_population integer not null default 0,
  housed_population integer not null default 0,
  employed_population integer not null default 0,
  unhoused_population integer not null default 0,
  happiness numeric not null default 50,
  updated_at timestamptz not null default now(),
  check (total_population >= 0),
  check (housed_population >= 0),
  check (employed_population >= 0),
  check (unhoused_population >= 0),
  check (happiness >= 0 and happiness <= 100)
);

create table if not exists public.trade_offers (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  from_player_id uuid not null references public.player_profiles(id) on delete cascade,
  to_player_id uuid references public.player_profiles(id) on delete cascade,
  offer_resource_key text not null references public.resource_types(key),
  offer_amount numeric not null,
  want_resource_key text references public.resource_types(key),
  want_amount numeric,
  ask_gold integer,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  check (status in ('open', 'accepted', 'cancelled', 'expired', 'rejected')),
  check (offer_amount > 0),
  check (want_amount is null or want_amount > 0),
  check (ask_gold is null or ask_gold >= 0)
);

create table if not exists public.trade_transactions (
  id uuid primary key default gen_random_uuid(),
  trade_offer_id uuid references public.trade_offers(id) on delete set null,
  seller_player_id uuid not null references public.player_profiles(id) on delete cascade,
  buyer_player_id uuid not null references public.player_profiles(id) on delete cascade,
  resource_key text not null references public.resource_types(key),
  amount numeric not null,
  gold_total integer,
  created_at timestamptz not null default now(),
  check (amount > 0),
  check (gold_total is null or gold_total >= 0)
);

create table if not exists public.player_notifications (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.player_profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.player_profiles
  add constraint player_profiles_home_district_fk
  foreign key (home_district_id) references public.districts(id) on delete set null;

create index if not exists idx_districts_world_id on public.districts(world_id);
create index if not exists idx_tiles_world_xy on public.tiles(world_id, x, y);
create index if not exists idx_tiles_district_id on public.tiles(district_id);
create index if not exists idx_tiles_owner_player_id on public.tiles(owner_player_id);
create index if not exists idx_buildings_world_id on public.buildings(world_id);
create index if not exists idx_buildings_district_id on public.buildings(district_id);
create index if not exists idx_buildings_owner_player_id on public.buildings(owner_player_id);
create index if not exists idx_trade_offers_world_id on public.trade_offers(world_id);
create index if not exists idx_trade_offers_from_player_id on public.trade_offers(from_player_id);
create index if not exists idx_trade_offers_to_player_id on public.trade_offers(to_player_id);
create index if not exists idx_notifications_player_id_created_at on public.player_notifications(player_id, created_at desc);

create trigger set_player_profiles_updated_at
before update on public.player_profiles
for each row execute function public.set_updated_at();

create trigger set_buildings_updated_at
before update on public.buildings
for each row execute function public.set_updated_at();

create trigger set_player_treasuries_updated_at
before update on public.player_treasuries
for each row execute function public.set_updated_at();

create trigger set_player_inventories_updated_at
before update on public.player_inventories
for each row execute function public.set_updated_at();

create trigger set_population_state_updated_at
before update on public.population_state
for each row execute function public.set_updated_at();

insert into public.resource_types (key, name, category, base_value)
values
  ('timber', 'Timber', 'raw', 10),
  ('stone', 'Stone', 'raw', 12),
  ('grain', 'Grain', 'raw', 8),
  ('wood_planks', 'Wood Planks', 'processed', 22),
  ('masonry', 'Masonry', 'processed', 26),
  ('flour', 'Flour', 'processed', 18)
on conflict (key) do nothing;

insert into public.building_types (key, name, category, footprint_w, footprint_h, cost_gold, maintenance_gold, required_resource_key, output_resource_key, build_rules)
values
  ('road', 'Road', 'infrastructure', 1, 1, 5, 0, null, null, '{"placeOn": ["buildable"]}'::jsonb),
  ('lumber_camp', 'Lumber Camp', 'extraction', 1, 1, 100, 1, 'timber', 'timber', '{"mustMatchResource": true}'::jsonb),
  ('quarry', 'Quarry', 'extraction', 1, 1, 100, 1, 'stone', 'stone', '{"mustMatchResource": true}'::jsonb),
  ('grain_farm', 'Grain Farm', 'extraction', 1, 1, 100, 1, 'grain', 'grain', '{"mustMatchResource": true}'::jsonb),
  ('warehouse', 'Warehouse', 'storage', 1, 1, 150, 1, null, null, '{"storageBonus": 100}'::jsonb),
  ('housing', 'Housing', 'housing', 1, 1, 120, 0, null, null, '{"populationCap": 10}'::jsonb)
on conflict (key) do nothing;

insert into public.worlds (slug, name, status, width, height)
values ('alpha-world', 'Alpha World', 'active', 32, 32)
on conflict (slug) do nothing;
